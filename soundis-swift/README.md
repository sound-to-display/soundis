# soundis (Swift)

macOS(Tahoe 26+)용 오디오 반응형 **은하 비주얼라이저**. 마이크나 시스템에서 재생 중인
소리를 실시간 캡처해, 우주의 다양한 은하 형태 8종 중 하나로 시각화합니다. 네이티브
Swift(AppKit + Core Graphics + ScreenCaptureKit) + macOS 26 Liquid Glass UI.

## 개발 모드로 실행

```bash
swift run
```

무음 상태에서도 은하가 천천히 회전하며 색이 드리프트합니다. **개발 바이너리에는
Info.plist가 없어 마이크·시스템 오디오 권한을 못 받습니다.** 실제 오디오는 아래 앱
번들을 쓰세요.

## 앱 번들 빌드 · 설치

```bash
./Scripts/make-signing-cert.sh   # 최초 1회: 안정적 자체 서명 인증서 생성
./Scripts/make-app.sh            # build/Soundis.app 생성 (그 인증서로 서명)
open build/Soundis.app
```

안정 서명 덕분에 **한 번 허용한 권한(마이크·화면 기록)이 재빌드·재실행 후에도 유지**됩니다.

- **마이크**: MIC 버튼을 처음 누르면 접근 권한 대화상자가 뜹니다.
- **시스템 오디오**: SYSTEM 버튼이 화면 기록 권한을 확인합니다. 없으면 시스템 설정의
  화면 기록 창을 자동으로 열어줍니다. Soundis를 켠 뒤 **앱을 한 번 재실행**하면
  캡처됩니다. (오디오만 쓰지만 macOS 정책상 화면 기록 권한이 필요합니다.)

## 조작

- **MIC / SYSTEM** — 입력 소스 전환
- **테마 이름 클릭** — 은하 선택 피커(카드 그리드) 열기 · Esc/바깥 클릭으로 닫기
- **◀ / ▶ 버튼**, **← / → 방향키** — 은하 순환 · **숫자키 1–8** — 직접 선택
- **밀도 슬라이더** — 별 밀도(높이면 촘촘+작게, 낮추면 띄엄띄엄+크게)

## 은하 형태 (8종)

SPIRAL(나선) · BARRED(막대나선) · ELLIPTICAL(타원) · IRREGULAR(불규칙) ·
RING(고리) · LENTICULAR(렌즈) · PECULIAR(상호작용 쌍) · POLAR RING(폴라 링).

모두 공통 렌더러를 공유하며, 저음/고음에 색조가 따뜻/차갑게 밀리고, 비트에 코어가
플레어하며 카메라가 흔들립니다.

## 구조

- `AudioSourceManager` — AVAudioEngine(마이크) / ScreenCaptureKit(시스템)에서 캡처,
  512-point vDSP FFT로 Web Audio analyser 동작(스무딩 + dB 바이트 스케일)을 재현.
- `Frame` — 매 프레임 재사용되는 단일 구조체. bass/mid/treble/level(0–1),
  bins(256, 0–1), waveform(512, −1…1), time/dt(초).
- `StageView` — CVDisplayLink 렌더 루프 + 테마 생명주기 + 250ms 딥-스루 전환.
- `Galaxy/GalaxyTheme` — 8종이 공유하는 오디오 반응 렌더러(3D 투영·카메라·색·밀도·
  코어 블룸). 별 위치는 첫 프레임에 지연 생성.
- `Galaxy/Morphology` + `Galaxy/Morphologies/*` — 형태별 별 분포 생성기. 각자
  `generate(into:count:)`로 `GalaxyStars`(bx/by/bz·dist·spin…)를 채웁니다.
- `ControlsView` / `ThemePickerView` — SwiftUI Liquid Glass 컨트롤 바 + 피커.
