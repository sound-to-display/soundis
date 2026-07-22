# Soundis: Audio-Reactive Visualizer — Design

## Purpose

macOS(Sequoia 15+) 전용 Electron 데스크톱 앱. 마이크 또는 시스템 오디오(유튜브, 스포티파이 등)를
실시간으로 캡처해 Three.js 파티클로 시각화한다. 재즈/시티팝 LP를 틀어놓고 반응을 보는 것이
주 용도이므로 지연 최소화가 최우선이며, 서버 왕복 없이 전부 로컬 처리한다.

## Scope

이번 작업은 저음 반응 링(기존 계획)에 더해 3-band(저/중/고음) 반응까지 포함한
베이스라인을 처음부터 구현한다. 별도 파티클 레이어, 스펙트럼 바 모드 등은 범위 밖이며
추후 별도 세션에서 다룬다.

## Confirmed Technical Decisions

- Electron 데스크톱 앱 (브라우저 앱 아님) — 시스템 오디오 전체 캡처를 위해 필요
- 시스템 오디오 캡처: Electron 네이티브 API (`session.setDisplayMediaRequestHandler` +
  `desktopCapturer`). 원래는 `electron-audio-loopback` 패키지를 쓸 계획이었으나, 이
  패키지는 공식적으로 `Electron >=31.0.1 <39.0.0`만 지원하며 39 이상에서는 "필요 없다"고
  명시하고 있다. macOS CoreAudio Tap 네이티브 지원이 정확히 Electron 39부터 Chromium에
  내장됐고, 현재 최신 안정 버전은 43.x이므로 별도 패키지 없이 네이티브 API로 구현한다
  (의존성 하나 감소 + 최신 Electron 유지 가능)
- 패키징: `electron-builder`로 macOS `.app` 빌드. macOS 14.2+에서는 `desktopCapturer`
  오디오 캡처에 `NSAudioCaptureUsageDescription` Info.plist 키가 반드시 있어야 하는데,
  `electron .`으로 개발 모드 실행 시 쓰이는 Electron 바이너리의 기본 Info.plist에는
  이 키가 없어 시스템 오디오 캡처가 조용히 실패(무음)할 수 있다. 따라서 `electron-builder`의
  `mac.extendInfo`로 `NSAudioCaptureUsageDescription`과 `NSMicrophoneUsageDescription`을
  명시한 빌드 결과물(.app)로 실행해야 시스템 오디오 캡처가 확실히 동작한다
- 렌더링: Three.js, Web Audio API `AnalyserNode`의 주파수 데이터로 파티클 실시간 구동
- `fftSize: 512` (지연 vs 해상도 트레이드오프, 필요시 축소 가능)
- 톤: 어두운 배경 + 따뜻한 앰버(`#e0a458`) 포인트 컬러, 아날로그 믹싱 콘솔 느낌의 미니멀 UI
  (모노스페이스 폰트, 하단 토글 버튼)
- 보안 모델: `nodeIntegration: true` / `contextIsolation: false` — 개인용 로컬 툴이므로
  이 단계에서는 이 정도로 충분

## File Structure

```
soundis/
├── package.json          # electron, electron-builder, three 의존성 + build 설정(mac.extendInfo)
├── main.js                # Electron 메인 프로세스, setDisplayMediaRequestHandler로
│                          # 시스템 오디오 루프백 등록 + BrowserWindow 생성
├── renderer/
│   ├── index.html         # UI 셸 (다크 배경, 모노스페이스, 하단 토글)
│   ├── style.css          # 믹싱 콘솔 톤 스타일
│   ├── renderer.js        # 진입점: audio.js + visualizer.js 조립, 소스 전환 UI 로직
│   ├── audio.js           # 오디오 캡처 + 3-band 분석 (순수 함수 위주, 테스트 가능)
│   └── visualizer.js      # Three.js 파티클 링 씬 + 3-band 매핑 렌더링
├── test/
│   └── bands.test.js      # 대역 분할/에너지 계산 순수 함수 유닛 테스트 (node --test)
└── README.md              # 설치/실행법, macOS 권한 관련 메모
```

**분리 이유**: 오디오 분석(순수 로직, 테스트 가능)과 Three.js 렌더링(부수효과 많음)을
분리해 대역 분할 계산을 유닛테스트로 검증할 수 있게 한다. `renderer.js`는 둘을 연결하는
조립 지점 역할만 한다.

## Audio Pipeline

- **마이크 입력**: `navigator.mediaDevices.getUserMedia({ audio: true })`
- **시스템 오디오 입력**: 메인 프로세스에서 `session.defaultSession.setDisplayMediaRequestHandler`를
  등록해 `desktopCapturer.getSources({ types: ['screen'] })`로 얻은 첫 화면 소스와
  `audio: 'loopback'`을 콜백으로 반환한다. 렌더러에서는 `getDisplayMedia({ video: true, audio: true })`를
  호출하면 시스템 오디오가 포함된 스트림을 받는다 (video 요청이 없으면 실패하므로 반드시
  같이 요청). video 트랙은 받은 즉시 정지·제거한다 (오디오만 필요)
- **소스 전환**: 기존 `MediaStream` 트랙 정지 → 새 스트림 획득 → 기존 `AudioContext`는
  재사용하고 `MediaStreamAudioSourceNode`만 교체한다 (AudioContext를 매번 재생성하지
  않아 전환 시 클릭 노이즈·딜레이를 최소화)
- 단일 `AnalyserNode(fftSize: 512)`에서 `getByteFrequencyData()`로 매 프레임 주파수 데이터를
  읽는다. 대역별 AnalyserNode를 3개 두는 방식은 매 프레임 FFT 연산이 3배가 되어 레이턴시
  목표와 어긋나므로 채택하지 않는다.
- bin 인덱스를 주파수 범위로 환산해 3구간 평균을 계산한다:
  - 저음: 약 20–250Hz
  - 중음: 약 250–4000Hz
  - 고음: 약 4000Hz 이상
- `audio.js`에 순수 함수로 분리:
  - `computeBandRanges(sampleRate, fftSize)` → 각 대역의 bin 인덱스 범위 반환
  - `computeBandEnergies(dataArray, ranges)` → 각 대역의 평균 에너지(0–255) 반환

## Visualization Mapping

기존 링 파티클 구조를 유지하며 3-band 매핑을 추가한다:

- **저음(bass)** → 링 반지름 스케일 (기존 동작 유지)
- **중음(mid)** → 링 그룹의 회전 속도 (`group.rotation.z` 증가량 — 카메라가 정면을 보므로
  Z축 회전이 "돌아가는 LP" 느낌을 준다. 3D 입체감을 위해 그룹에 고정된 `rotation.x` 틸트를
  살짝 준다)
- **고음(treble)** → 파티클 색상의 밝기/채도 (`color.lerp(amber, treble)`, amber 톤은 유지)
  + 파티클 위치에 작은 랜덤 지터 오프셋

## Error Handling

- **마이크 권한 거부**: 화면에 "마이크 접근이 거부됐습니다. 시스템 설정에서 허용해주세요"
  안내를 표시하고 해당 소스 토글을 비활성화한다.
- **시스템 오디오 캡처 실패** (macOS 버전 미충족, Electron 버전 미달 등): 콘솔에 에러를
  로그하고 UI에 안내 문구를 표시한다. 마이크 모드로 자동 폴백하지 않고, 사용자가 직접
  재시도하도록 둔다.

## Testing Plan

- `computeBandRanges`, `computeBandEnergies` 등 순수 함수는 Node 내장 테스트 러너
  (`node --test`)로 유닛 테스트한다. 외부 테스트 프레임워크는 추가하지 않는다.
- Three.js 렌더링과 Electron 오디오 캡처는 유닛테스트 대상이 아니다. 마이크 토글은
  `npm start` 개발 모드로도 확인 가능하지만, 시스템 오디오 캡처는 `NSAudioCaptureUsageDescription`
  키가 포함된 패키지 빌드(`npm run build` → 생성된 `.app` 실행)에서만 신뢰성 있게
  확인할 수 있다. 다음을 수동 확인한다:
  - 마이크 토글 시 소리에 반응하는지 (개발 모드에서 확인 가능)
  - 패키지 빌드된 `.app`에서 시스템 오디오 토글 후 유튜브/스포티파이 등 재생 중인
    소리에 반응하는지
  - 소스 전환 시 클릭 노이즈나 긴 끊김 없이 매끄럽게 전환되는지
