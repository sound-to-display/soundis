# Soundis (Swift): 은하 형태 다양화 + 테마 피커 — Design

## Purpose

VORTEX(나선 은하) 하나뿐인 은하 시각화를 우주의 다양한 은하 형태로 확장한다. 6종의
은하를 각각 독립 테마로 만들고, 별도의 **정적 카드 그리드 피커** 화면에서 골라 전환한다.
색 다양화·밀도 슬라이더·오디오 반응·카메라 등 기존 연출은 6종 모두가 공유한다.

## Scope

- `VortexTheme`의 공통 로직을 재사용 가능한 **`GalaxyTheme`** 베이스로 리팩터.
- 형태별 **분포 생성기(Morphology)** 6종: SPIRAL, BARRED, ELLIPTICAL, IRREGULAR, RING, LENTICULAR.
- **테마 피커**: Liquid Glass 오버레이 카드 그리드. 테마 이름 클릭으로 열고, 카드 클릭/바깥
  클릭/Esc로 닫는다. 은하 6종 + 기존 4종(WARP·SEISMO·RAIN·INVADERS) 총 10개 표시.
- **밀도 슬라이더**를 은하 계열 전체에서 표시(현재는 VORTEX 전용).

범위 밖: 형태 간 실시간 모프(보간), 라이브 미니 프리뷰 렌더링, 은하 형태 저장(재시작 시
첫 테마로 시작), GPU 후처리.

## Architecture

### GalaxyTheme (공통 베이스)

`VortexTheme`를 일반화한다. 별마다 **모델 공간 기본 3D 위치**와 부가 속성을 갖는다:

```
bx, by, bz : Double   // 은하 로컬 좌표계의 기본 위치
dist       : Double   // 0…1 정규화 반경 (색 hue 분산 + frame.bins 조회용)
spin       : Double   // 시간 회전 가중치 (Y축). 나선=1.6-dist(차등), 타원=~0.4, 나머지≈1
phase, speed : Double // 트윙클/시머 애니메이션
haze       : Double   // 0/1 필드별 vs 코어별 (밝기·채도 낮춤)
```

`Morphology`는 이 배열들을 `init`에서 채우는 함수(또는 프로토콜):

```swift
protocol Morphology { var name: String { get }; var accent: RGB { get }
    func generate(count: Int, into stars: inout GalaxyStars) }
```

`GalaxyTheme(morphology:)`가 하나의 테마 인스턴스가 된다(`id`/`name`/`palette`는 morphology에서).

### Draw 파이프라인 (공유)

매 프레임(기존 로직 재사용):
1. `baseHue`(시간 드리프트 + 저음 워밍/고음 쿨링), `coreColor` 계산.
2. 카메라: `cxS/cyS` 스웨이(+비트 킥), `camOrbit`(에너지 가속), `tiltY`, `roll`.
3. 밀도로 그릴 별 수(`drawn`)·도트 크기·알파 계산.
4. 각 별: 기본 `(bx,bz)`를 `rotation*spin`만큼 Y축 회전 → `breath` 스케일 →
   `y = by*breath + 오디오 lift + shimmer` → 카메라 투영(orbit·tilt·roll·sway) →
   hue = `baseHue + dist*0.42 + arm오프셋`, 채도·밝기 = glow, 크기 = 밀도. 가산 블렌딩.
5. 코어 블룸(부드러운 타원형 다중 로브) + 비트 플레어.

기존 VORTEX는 이 파이프라인의 spiral morphology로 정확히 재현된다
(`bx=cos(baseAngle+dist*twist)*r0`, `bz=sin(...)*r0`, `by=0`, `spin=1.6-dist`).

### Morphology 6종 생성 방식

- **SPIRAL** — 로그나선 팔(`arm/arms*2π + dist*twist`) + 산개 필드별. `spin=1.6-dist`(차등).
- **BARRED** — 안쪽(dist<0.4)은 x축으로 늘이고 z축 압축한 **막대**, 바깥은 막대 양끝에서
  뻗는 2개 팔. `spin=1.6-dist`.
- **ELLIPTICAL** — 팔 없는 3D 타원체: 균일 구면 방향 × `r0`(=dist*radius), y축 0.7 압축.
  `by`가 실제 부피를 가짐. `spin≈0.4`(느린 강체 회전).
- **IRREGULAR** — 5~8개 클럼프 중심을 무작위 배치, 각 별을 클럼프에 배정 후 가우시안
  산포. 비대칭. `spin≈0.6` 완만한 텀블.
- **RING** — `r0`을 링 반경 부근(dist≈1, 좁은 산포)에 집중, 중심 비움, 얇은 두께(by 소).
  `spin≈1.0` 균일.
- **LENTICULAR** — 매끄러운 원반(팔 없음, 균일 각도) + 구형 중심 팽대부(bulge, 3D 밀집).
  `spin=1.4-dist`.

각 morphology는 자기 accent 색(글래스 UI 틴트용)을 갖는다. 별 색 자체는 공통 hue 드리프트.

### ThemeRegistry

`[SPIRAL, BARRED, ELLIPTICAL, IRREGULAR, RING, LENTICULAR, WARP, SEISMO, RAIN, INVADERS]`
— 은하 6종이 앞, 기존 비-은하 4종이 뒤. 숫자키 1–9 + ◀▶/피커로 전환.

## Picker UI (정적 카드 그리드)

- **`ThemePickerView`** (SwiftUI): 반투명 dim 배경 + 중앙 Liquid Glass 패널, 카드 그리드.
- **카드**: 은하 6종은 형태별 **정적 미니 도형**(SwiftUI `Canvas`로 1회 그림 — 나선/막대/
  타원/산개/고리/원반), 나머지 4종은 대표 **SF Symbol**. 아래에 이름. 글래스 스타일,
  현재 선택 카드는 accent 테두리 강조.
- **열기**: 하단 컨트롤 바의 **테마 이름을 버튼으로** → `ControlsModel.pickerOpen = true`.
- **닫기/선택**: 카드 클릭 → `onSelectTheme(index)` 호출 후 닫힘; 바깥 클릭/Esc → 닫힘.
- ◀▶ 순환·숫자키는 그대로 유지(피커는 추가 수단).

## Controls 통합

- `ControlsModel`: `@Published var pickerOpen`, `@Published var isGalaxy`,
  `@Published var themes: [(name, isGalaxy)]`, `@Published var currentIndex`;
  콜백 `onSelectTheme: (Int)->Void`.
- **밀도 슬라이더**: `if model.isGalaxy` 일 때 표시(테마 이름 문자열 비교 대신 플래그).
- `AppDelegate`: 테마 변경 시 `isGalaxy`(현재 테마가 `GalaxyTheme`인지) + `currentIndex`
  갱신. `onSelectTheme = { stage.setTheme($0) }`. 피커 열림 상태는 키보드 Esc로도 닫음.

## Data flow

```
Picker 카드 클릭 → ControlsModel.onSelectTheme(i) → AppDelegate → StageView.setTheme(i)
                → onThemeChange → ControlsModel(themeName/isGalaxy/currentIndex, pickerOpen=false)
밀도 슬라이더 → ControlsModel.onDensity → StageView.setDensity → GalaxyTheme.setDensity
```

## Error / edge cases

- 전환 중(dip-through) 피커 선택 → 기존 `setTheme` 가드(transitioning)로 자연 무시.
- 비-은하 테마에서 밀도 슬라이더 숨김(`isGalaxy=false`).
- 별 수는 morphology마다 동일 풀(6500)에서 밀도로 스케일.

## Testing

- 각 morphology를 `SOUNDIS_THEME=<i> SOUNDIS_CAPTURE=<png>` 오프스크린 렌더로 형태 확인
  (오디오·권한 불필요). 밀도 극단값(`SOUNDIS_DENSITY`)도 캡처 비교.
- 피커: 열기→카드 선택→적용/닫힘, 바깥/Esc 닫힘을 수동 확인(라이브 창).
- 빌드 클린(`swift build`) + 안정 서명 번들로 실행.
