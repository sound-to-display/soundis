# soundis (Swift)

macOS(Sonoma 14+)용 오디오 반응형 비주얼라이저. Electron/Three.js 프로토타입을
네이티브 Swift(AppKit + Core Graphics + ScreenCaptureKit)로 포팅한 버전입니다.
마이크 또는 시스템에서 재생 중인 소리를 실시간 캡처해 5개 레트로 테마 중 하나로
시각화합니다.

## 개발 모드로 실행

```bash
swift run
```

창이 뜨면 유휴(무음) 상태에서도 테마별 애니메이션이 돕니다. **개발 모드 바이너리에는
Info.plist가 없어 마이크·시스템 오디오 권한을 받을 수 없습니다.** 실제 오디오 테스트는
아래 앱 번들 빌드를 사용하세요.

## 앱 번들 빌드 (오디오 권한 테스트용)

```bash
./Scripts/make-app.sh
open build/Soundis.app
```

- **마이크**: MIC 버튼을 처음 누르면 마이크 접근 권한 대화상자가 뜹니다.
- **시스템 오디오**: SYSTEM 버튼을 처음 누르면 ScreenCaptureKit이 화면 기록 권한을
  요구합니다. 시스템 설정 › 개인정보 보호 및 보안 › 화면 기록에서 Soundis를 허용한 뒤
  다시 눌러주세요. (오디오만 쓰지만 macOS 정책상 화면 기록 권한이 필요합니다.)

## 조작

- **MIC / SYSTEM** — 입력 소스 전환
- **◀ / ▶ 버튼**, **← / → 방향키** — 테마 순환
- **숫자키 1–5** — 테마 직접 선택

## 테마

| # | 이름 | 원본(JS) | 설명 |
|---|------|----------|------|
| 1 | VORTEX | ring | 무드 컬러 그레이딩 나선 은하 |
| 2 | WARP | horizon | 코르크스크루 웜홀 터널 |
| 3 | SEISMO | console | 스프링 잉크펜 스트립차트 레코더 |
| 4 | RAIN | scope | CRT 디지털 레인(매트릭스) |
| 5 | INVADERS | arcade | 8비트 스펙트럼 인베이더 함대 |

## 구조

- `AudioSourceManager` — AVAudioEngine(마이크) / ScreenCaptureKit(시스템)에서 캡처,
  512-point vDSP FFT로 Web Audio analyser 동작(스무딩 + dB 바이트 스케일)을 재현.
- `Frame` — 매 프레임 재사용되는 단일 구조체. bass/mid/treble/level(0–1),
  bins(256, 0–1), waveform(512, −1…1), time/dt(초).
- `StageView` — CVDisplayLink 렌더 루프 + 테마 생명주기 + 250ms 딥-스루 전환.
- `Theme` / `Themes/*` — 각 테마는 `update(frame:)`로 상태를 진행하고
  `draw(in:size:)`로 Core Graphics에 그립니다.

포팅 원본은 리포지토리의 `soundis-themes` 브랜치(`.worktrees/themes/soundis/`,
`renderer/themes/*.js`)입니다.
