# Soundis: 테마 시스템 + 5개 비주얼 테마 — Design

## Purpose

기존 단일 앰버 파티클 링을 5개 테마 중 하나로 확장한다. 사용자는 하단 셀렉터나
숫자키(1–5)로 테마를 전환하고, 테마마다 시각화 방식·팔레트·UI 색이 함께 바뀐다.
"레트로하고 굉장히 이쁜" 방향으로 신스웨이브/아날로그 하이파이/CRT/픽셀 감성을
각각 하나의 테마로 구현한다.

## Scope

- 테마 시스템 (stage 생명주기 관리 + 레지스트리 + 전환 연출)
- 5개 테마: RING(기존), HORIZON(신스웨이브), CONSOLE(70s 하이파이 VU),
  SCOPE(CRT 오실로스코프), ARCADE(8비트 픽셀 바)
- 테마별 UI 재스킨 (CSS 커스텀 프로퍼티)
- 테마 전환 딥-스루 트랜지션
- 유휴(idle) 연출: 모든 테마는 무음/미연결 상태에서도 시간 기반으로 은은히 움직임
- 창 프레임: `titleBarStyle: 'hiddenInset'` 몰입형 + 드래그 영역

범위 밖: GPU 후처리(블룸 등), 테마 설정 저장(재시작 시 첫 테마로 시작), 커스텀 테마.

## Architecture (Approach A: 테마 = 독립 모듈, 캔버스 자율)

각 테마는 컨테이너를 통째로 받아 자기 캔버스를 만들고 스스로 그린다. Three.js를
쓸지 2D 캔버스를 쓸지는 테마 내부 결정이다. 전부 Three.js로 통일하는 안(B)은 VU
바늘·픽셀 그리드를 3D로 억지 구현해야 해서 기각. 테마 전환은 수동 조작이므로
WebGL 컨텍스트 재생성 비용(~100ms)은 전환 페이드에 묻힌다.

### Theme Interface

```js
// renderer/themes/<id>.js
module.exports = {
  id: 'horizon',           // 고유 id (레지스트리 키)
  name: 'HORIZON',         // 셀렉터 표시명 (대문자, 모노스페이스)
  palette: {               // stage가 CSS 변수로 적용
    bg: '#12081f',         // 캔버스/문서 배경
    accent: '#ff4fd8',     // 버튼·셀렉터·상태 텍스트
    dim: '#5a3a7a',        // 비활성/보조
  },
  create(container) {      // 마운트: 캔버스 생성, 씬 구성
    return {
      update(frame),       // 매 프레임 호출
      resize(w, h),        // stage가 창 리사이즈 시 호출
      dispose(),           // 언마운트: 캔버스 제거, 리소스/컨텍스트 해제
    };
  },
};
```

`frame` 객체 (stage가 만들어 전달, 매 프레임 재사용되는 단일 객체):

```js
{
  bass, mid, treble,  // 0–1 정규화 (energies/255)
  level,              // (bass+mid+treble)/3 — 유휴 판단 등에 사용
  waveform,           // Uint8Array (time-domain, SCOPE용. 128=무음 중심)
  time,               // 초 (performance.now()/1000)
  dt,                 // 직전 프레임과의 간격(초)
}
```

**유휴 요구사항**: 모든 테마는 `level ≈ 0`일 때도 `time` 기반의 잔잔한 애니메이션
(숨쉬기, 드리프트, 스캔 등)을 보여야 한다. 별도 idle 모드는 두지 않는다 —
각 테마의 update가 저에너지 구간을 자연스럽게 처리한다.

### File Structure

```
renderer/
  audio.js            # 기존 + getWaveform() 추가 (getByteTimeDomainData, 배열 재사용)
  stage.js            # 신규: 테마 생명주기, rAF 루프, frame 조립, 전환, 팔레트 적용, 리사이즈
  themes/
    index.js          # 레지스트리: 순서 있는 테마 배열 [ring, horizon, console, scope, arcade]
    ring.js           # 기존 visualizer.js를 테마 인터페이스로 이식
    horizon.js        # 신스웨이브 (Three.js)
    console.js        # 70s VU 미터 (2D canvas)
    scope.js          # CRT 오실로스코프 (2D canvas)
    arcade.js         # 8비트 픽셀 바 (2D canvas)
  renderer.js         # 글루: MIC/SYSTEM 버튼, 테마 셀렉터/키보드 → stage 호출
  index.html          # 셀렉터 마크업, 드래그 영역 추가
  style.css           # CSS 커스텀 프로퍼티(--bg, --accent, --dim) 기반으로 재작성
main.js               # titleBarStyle: 'hiddenInset' 추가
renderer/visualizer.js  # 삭제 (ring.js로 이식)
```

**rAF 루프 소유권이 renderer.js → stage.js로 이동한다.** 전환 중에도 stage가
렌더링을 계속 제어해야 하기 때문. `renderer.js`는 컨트롤 배선만 남는다.

### Stage API

```js
const stage = createStage(container, { getFrame });
// getFrame(): renderer.js가 AudioSourceManager에서 frame 데이터를 만들어 반환

stage.themes            // [{id, name}] 표시용
stage.currentIndex      // 현재 테마 인덱스
stage.setTheme(index)   // 전환 (트랜지션 포함, 진행 중 재호출은 무시)
stage.next() / stage.prev()
stage.onThemeChange(cb) // 셀렉터 라벨 갱신용
```

### 전환 (딥-스루)

컨테이너를 덮는 오버레이 div를 다음 테마의 `palette.bg`로 250ms 페이드 인 →
이전 테마 `dispose()`, 새 테마 `create()`, CSS 변수 교체 → 250ms 페이드 아웃.
CRT 채널 전환 느낌의 의도된 연출이며 캔버스 종류(WebGL/2D)와 무관하게 동작한다.
전환 중 `setTheme` 재호출은 무시한다(중복 방지).

### 팔레트 → UI 재스킨

stage가 테마 마운트 시 `document.documentElement.style.setProperty('--bg', ...)`
등으로 CSS 변수를 갱신. `style.css`의 모든 색은 `var(--bg)`, `var(--accent)`,
`var(--dim)`을 참조하도록 재작성한다. 색 전환은 CSS `transition`으로 부드럽게.
폰트는 전 테마 공통 모노스페이스 유지(앱 정체성).

## 5개 테마 사양

| # | id | name | 방식 | 팔레트(bg/accent/dim) | 3-band 매핑 |
|---|-----|------|------|------|------|
| 1 | ring | RING | Three.js 파티클 링 | `#0a0a0a` / `#e0a458` / `#5a4a38` | 기존 유지: 저음=반지름, 중음=Z회전, 고음=밝기+지터 |
| 2 | horizon | HORIZON | Three.js 원근 그리드 | `#12081f` / `#ff4fd8` / `#5a3a7a` | 저음=그리드 융기(지형), 중음=스크롤 속도, 고음=태양 글로우·별 스파클 |
| 3 | console | CONSOLE | 2D canvas VU 미터 | `#241a12` / `#e8873a` / `#7a5c40` | 저음=좌 바늘, 고음=우 바늘, 중음=양쪽 보조, 피크 시 램프 점등 |
| 4 | scope | SCOPE | 2D canvas 파형 | `#050805` / `#4dff6a` / `#1d5a28` | 파형 직접 표시(time-domain), 저음=빔 굵기, 고음=밝기·지터 |
| 5 | arcade | ARCADE | 2D canvas 픽셀 바 | `#10122b` / `#ffd23e` / `#4a4e8a` | 주파수 바(블록 양자화)+낙하 피크 캡, 저음=전체 바운스 |

세부 연출 노트:

- **HORIZON**: 화면 하단 2/3가 소실점으로 수렴하는 그리드 평면, 상단에 수평 슬랫이
  들어간 태양 원반과 그라데이션 하늘. 그리드 라인 정점이 저음에 융기해 지형처럼
  출렁임. 시안(`#40e0ff`) 보조 글로우 허용.
- **CONSOLE**: 바늘은 스프링-감쇠 물리(순수 함수로 분리, 테스트 대상)로 아날로그
  관성을 표현. 크림색 다이얼 페이스, 눈금·라벨(dB 표기), 피크 램프는 임계 초과 시
  점등 후 서서히 소등.
- **SCOPE**: 이전 프레임을 반투명 검정으로 덮어 인광 잔상(phosphor decay)을 만들고,
  격자 그래티큘·스캔라인·비네트를 얹는다. 무음 시 중앙 평탄선이 미세하게 떨림.
- **ARCADE**: 주파수 빈을 바 개수로 다운샘플(순수 함수, 테스트 대상)하고 블록 단위
  양자화. 피크 캡은 중력 낙하. NES풍 제한 팔레트(바 높이에 따라 색 단계).

## 오디오 확장

`AudioSourceManager`에 추가:

```js
getWaveform()  // analyser.getByteTimeDomainData(this.waveformArray) 후 반환
               // waveformArray는 생성자에서 fftSize 크기로 1회 할당, 재사용
```

소스 미연결 상태에서는 기존 `getBandEnergies()`처럼 무음 데이터(128 중심)가
나오므로 별도 분기 불필요.

## 컨트롤 & 창

- 하단 바: `MIC` `SYSTEM` 버튼(기존) + 구분선 + `◀ RING ▶` 셀렉터.
  ◀/▶ 클릭으로 prev/next, 숫자키 1–5로 직접 선택, ←/→ 방향키로도 prev/next.
- `main.js`: `titleBarStyle: 'hiddenInset'`. 상단 약 40px 투명 스트립에
  `-webkit-app-region: drag` 적용(버튼 영역은 `no-drag`). 상태 텍스트는 신호등
  버튼을 피해 배치.

## Error Handling

- 기존 마이크/시스템 오디오 에러 처리(문구·자동 폴백 없음·activeSource 복원)는
  변경하지 않는다.
- 테마 `create()`가 예외를 던지면(예: WebGL 컨텍스트 실패) 콘솔에 로그하고 이전
  테마로 복귀를 시도하며 상태 텍스트에 "테마 전환에 실패했습니다"를 표시한다.

## Testing Plan

`node --test` 순수 함수 테스트 (모듈 require는 안전 — 브라우저 API는 create() 내부에서만 사용):

- **레지스트리 무결성**: 5개 테마, id 유일성, 각 테마에 `id/name/palette/create`
  존재, palette에 `bg/accent/dim` 모두 존재하고 `#rrggbb` 형식.
- **CONSOLE 바늘 물리**: `stepNeedle(state, target, dt)` 순수 함수 — 목표값 수렴,
  오버슈트 후 감쇠, dt=0 안정성.
- **ARCADE 다운샘플**: `binsToBars(dataArray, barCount)` 순수 함수 — 바 개수,
  범위(0–1), 빈 배열 처리.
- 렌더링·전환·창 프레임은 수동 확인: 5개 테마 각각 (a) 음악 반응 (b) 무음 유휴
  연출 (c) 전환 페이드 (d) UI 색 재스킨을 패키지 빌드로 확인.

## 기존 이슈 해소

이 리팩토링으로 이전 리뷰의 minor 지적 두 건이 함께 해결된다:

- resize 리스너 미해제 → stage가 단일 리스너를 소유하고 테마에는 `resize()`를
  호출해주므로 테마 dispose 시 리스너 누수가 없다.
- visualizer 재생성 불가 구조 → `dispose()` 계약으로 정식 해결.
