# soundis

macOS(Sequoia 15+)용 오디오 반응형 비주얼라이저. 마이크 또는 시스템에서 재생 중인
소리(유튜브, 스포티파이 등)를 실시간으로 캡처해 Three.js 파티클 링으로 시각화합니다.

## 개발 모드로 실행

```bash
npm install
npm start
```

마이크 모드는 개발 모드(`npm start`)에서도 정상 동작합니다. **시스템 오디오 모드는
개발 모드에서 무음으로 실패할 수 있습니다** — macOS 14.2+는 `desktopCapturer` 오디오
캡처에 `NSAudioCaptureUsageDescription` Info.plist 키를 요구하는데, `electron .`이
쓰는 Electron 기본 바이너리에는 이 키가 없기 때문입니다. 시스템 오디오는 아래 패키지
빌드로 테스트하세요.

## 패키지 빌드 (시스템 오디오 테스트용)

```bash
npm run build
open dist/mac-arm64/Soundis.app   # Apple Silicon. Intel이면 dist/mac/Soundis.app
```

## macOS 권한

- **마이크**: MIC 버튼을 처음 누르면 마이크 접근 권한 대화상자가 뜹니다. 거부하면
  시스템 설정 > 개인정보 보호 및 보안 > 마이크에서 앱을 허용해야 합니다.
- **화면 기록(Screen Recording)**: SYSTEM 버튼을 처음 누르면 `desktopCapturer`가
  화면 소스 목록을 요청하면서 화면 기록 권한 대화상자가 뜰 수 있습니다. 오디오만
  쓰지만 macOS 정책상 이 권한이 필요합니다. 시스템 설정 > 개인정보 보호 및 보안 >
  화면 기록에서 허용하세요.

## 설계 메모

- fftSize는 512로 고정 (지연 vs 주파수 해상도 트레이드오프). 더 낮은 지연이 필요하면
  `renderer/renderer.js`의 `new AudioSourceManager({ fftSize: 512 })` 값을 256으로
  낮출 수 있습니다.
- 저음(20–250Hz)은 링 반지름, 중음(250–4000Hz)은 회전 속도, 고음(4000Hz+)은 색상
  밝기와 위치 지터에 매핑됩니다. 상세 설계는
  `docs/superpowers/specs/2026-07-22-audio-visualizer-design.md` 참고.
- 시스템 오디오 캡처는 `electron-audio-loopback` 패키지 대신 Electron 네이티브
  `setDisplayMediaRequestHandler` + `desktopCapturer`를 사용합니다 (Electron 39+
  필요, 현재 43.x 기준으로 작성됨).
