# Soundis Audio Visualizer Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Soundis baseline — an Electron desktop app that captures microphone or macOS system audio and drives a Three.js particle ring in real time, reacting on three frequency bands (bass/mid/treble), with a packaged `.app` so system-audio capture actually works on macOS 14.2+.

**Architecture:** Electron main process registers a native `setDisplayMediaRequestHandler` for system-audio loopback (no `electron-audio-loopback` dependency — see spec). The renderer splits into three focused modules: `audio.js` (pure band-math + a `AudioSourceManager` class wrapping Web Audio capture/switching), `visualizer.js` (Three.js particle ring scene), and `renderer.js` (thin glue: wires DOM buttons to the manager and visualizer, drives the render loop). `electron-builder` packages the app with the macOS `Info.plist` keys required for audio capture.

**Tech Stack:** Electron ^43.2.0, Three.js ^0.185.1, electron-builder ^26.15.3, Node's built-in `node --test` runner (no external test framework).

## Global Constraints

- Target OS: macOS Sequoia 15+ only.
- `AnalyserNode.fftSize` must be `512` (latency vs. resolution tradeoff — do not change without cause).
- Point/accent color is amber `#e0a458`; background is dark (`#0a0a0a`); UI font is monospace.
- `BrowserWindow` webPreferences must be `nodeIntegration: true`, `contextIsolation: false` (personal local tool — no preload/contextBridge).
- No server round-trips; all audio processing is local.
- Do not add `electron-audio-loopback` — it only supports `Electron >=31.0.1 <39.0.0` and this project targets current Electron (43.x), which has native loopback support.
- macOS 14.2+ requires the `NSAudioCaptureUsageDescription` Info.plist key for `desktopCapturer` audio capture — the stock `electron .` dev binary lacks it, so system-audio capture must be verified against the `electron-builder` packaged `.app`, not dev mode.
- No external test framework — use Node's built-in `node --test`.

---

### Task 1: Project Scaffold

**Files:**
- Create: `package.json`
- Create: `.gitignore`

**Interfaces:**
- Produces: an installable Node project with `electron`, `electron-builder`, `three` resolvable via `require()`/`npx`. No `build` config yet (added in Task 8, once there's something to package).

- [ ] **Step 1: Create the directory skeleton**

```bash
mkdir -p renderer test
```

- [ ] **Step 2: Write `package.json`**

```json
{
  "name": "soundis",
  "version": "0.1.0",
  "description": "Local audio-reactive visualizer for mic and system audio (macOS)",
  "private": true,
  "main": "main.js",
  "scripts": {
    "start": "electron .",
    "test": "node --test test/",
    "build": "electron-builder --mac"
  },
  "devDependencies": {
    "electron": "^43.2.0",
    "electron-builder": "^26.15.3"
  },
  "dependencies": {
    "three": "^0.185.1"
  }
}
```

- [ ] **Step 3: Write `.gitignore`**

```
node_modules/
dist/
.DS_Store
```

- [ ] **Step 4: Install dependencies**

Run: `npm install`
Expected: completes with no errors, creates `node_modules/` and `package-lock.json`.

- [ ] **Step 5: Verify the toolchain resolves**

Run: `npx electron --version && node -e "require('three'); console.log('three OK')" && npx electron-builder --version`
Expected: prints an Electron version string (`v43.x.x`), then `three OK`, then an electron-builder version string. No errors.

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json .gitignore
git commit -m "soundis: scaffold project with electron, three, electron-builder"
```

---

### Task 2: Frequency Band Math (TDD)

**Files:**
- Create: `renderer/audio.js`
- Create: `test/bands.test.js`

**Interfaces:**
- Produces: `computeBandRanges(sampleRate: number, fftSize: number) -> { bass: {start,end}, mid: {start,end}, treble: {start,end} }` (bin index ranges, half-open `[start, end)`).
- Produces: `computeBandEnergies(dataArray: Uint8Array, ranges) -> { bass: number, mid: number, treble: number }` (each 0–255).
- Consumed by: `AudioSourceManager` (Task 3).

- [ ] **Step 1: Write the failing tests**

Create `test/bands.test.js`:

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const { computeBandRanges, computeBandEnergies } = require('../renderer/audio.js');

test('computeBandRanges splits bins into bass/mid/treble by frequency', () => {
  const ranges = computeBandRanges(48000, 512);
  assert.deepEqual(ranges, {
    bass: { start: 0, end: 3 },
    mid: { start: 3, end: 43 },
    treble: { start: 43, end: 256 },
  });
});

test('computeBandEnergies averages each range independently', () => {
  const ranges = {
    bass: { start: 0, end: 2 },
    mid: { start: 2, end: 4 },
    treble: { start: 4, end: 6 },
  };
  const dataArray = new Uint8Array([10, 20, 30, 40, 50, 60]);
  const energies = computeBandEnergies(dataArray, ranges);
  assert.deepEqual(energies, { bass: 15, mid: 35, treble: 55 });
});

test('computeBandEnergies returns 0 for an empty range', () => {
  const ranges = {
    bass: { start: 5, end: 5 },
    mid: { start: 0, end: 2 },
    treble: { start: 2, end: 4 },
  };
  const dataArray = new Uint8Array([100, 200, 50, 60]);
  const energies = computeBandEnergies(dataArray, ranges);
  assert.deepEqual(energies, { bass: 0, mid: 150, treble: 55 });
});
```

- [ ] **Step 2: Run the tests and verify they fail**

Run: `node --test test/bands.test.js`
Expected: FAIL — `Cannot find module '../renderer/audio.js'`.

- [ ] **Step 3: Implement the pure functions**

Create `renderer/audio.js`:

```js
const BASS_MAX_HZ = 250;
const MID_MAX_HZ = 4000;

function clampBin(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function computeBandRanges(sampleRate, fftSize) {
  const binCount = fftSize / 2;
  const freqPerBin = sampleRate / 2 / binCount;

  const bassEnd = clampBin(Math.round(BASS_MAX_HZ / freqPerBin), 1, binCount);
  const midEnd = clampBin(Math.round(MID_MAX_HZ / freqPerBin), bassEnd + 1, binCount);

  return {
    bass: { start: 0, end: bassEnd },
    mid: { start: bassEnd, end: midEnd },
    treble: { start: midEnd, end: binCount },
  };
}

function averageRange(dataArray, start, end) {
  if (end <= start) return 0;
  let sum = 0;
  for (let i = start; i < end; i++) {
    sum += dataArray[i];
  }
  return sum / (end - start);
}

function computeBandEnergies(dataArray, ranges) {
  return {
    bass: averageRange(dataArray, ranges.bass.start, ranges.bass.end),
    mid: averageRange(dataArray, ranges.mid.start, ranges.mid.end),
    treble: averageRange(dataArray, ranges.treble.start, ranges.treble.end),
  };
}

module.exports = { computeBandRanges, computeBandEnergies };
```

- [ ] **Step 4: Run the tests and verify they pass**

Run: `node --test test/bands.test.js`
Expected: PASS — 3 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add renderer/audio.js test/bands.test.js
git commit -m "soundis: add 3-band frequency range/energy pure functions"
```

---

### Task 3: AudioSourceManager (mic/system audio capture + switching)

**Files:**
- Modify: `renderer/audio.js` (append class, extend `module.exports`)

**Interfaces:**
- Consumes: `computeBandRanges`, `computeBandEnergies` (Task 2, same file).
- Produces: `class AudioSourceManager` with:
  - `constructor({ fftSize = 512 } = {})`
  - `async useMicrophone(): Promise<void>` — throws on permission denial.
  - `async useSystemAudio(): Promise<void>` — throws if loopback capture fails.
  - `getBandEnergies(): { bass: number, mid: number, treble: number }`
- Consumed by: `renderer.js` (Task 7).

- [ ] **Step 1: Append `AudioSourceManager` to `renderer/audio.js`**

Add below the existing `computeBandEnergies` function (before `module.exports`):

```js
class AudioSourceManager {
  constructor({ fftSize = 512 } = {}) {
    this.audioContext = new AudioContext();
    this.analyser = this.audioContext.createAnalyser();
    this.analyser.fftSize = fftSize;
    this.dataArray = new Uint8Array(this.analyser.frequencyBinCount);
    this.bandRanges = computeBandRanges(this.audioContext.sampleRate, fftSize);
    this.currentStream = null;
    this.sourceNode = null;
  }

  async useMicrophone() {
    await this.audioContext.resume();
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    this._switchStream(stream);
  }

  async useSystemAudio() {
    await this.audioContext.resume();
    const stream = await navigator.mediaDevices.getDisplayMedia({
      video: true,
      audio: true,
    });
    stream.getVideoTracks().forEach((track) => {
      track.stop();
      stream.removeTrack(track);
    });
    this._switchStream(stream);
  }

  _switchStream(stream) {
    if (this.sourceNode) {
      this.sourceNode.disconnect();
    }
    if (this.currentStream) {
      this.currentStream.getTracks().forEach((track) => track.stop());
    }
    this.currentStream = stream;
    this.sourceNode = this.audioContext.createMediaStreamSource(stream);
    this.sourceNode.connect(this.analyser);
  }

  getBandEnergies() {
    this.analyser.getByteFrequencyData(this.dataArray);
    return computeBandEnergies(this.dataArray, this.bandRanges);
  }
}
```

- [ ] **Step 2: Update `module.exports`**

Change the last line of `renderer/audio.js` to:

```js
module.exports = { computeBandRanges, computeBandEnergies, AudioSourceManager };
```

- [ ] **Step 3: Syntax-check the file**

Run: `node --check renderer/audio.js`
Expected: no output, exit code 0. (`AudioContext`/`navigator` are only referenced inside method bodies, so this parses fine in plain Node even though it can't be executed there.)

- [ ] **Step 4: Re-run the existing pure-function tests as a regression check**

Run: `npm test`
Expected: PASS — same 3 tests from Task 2 still pass (confirms the module still loads correctly).

- [ ] **Step 5: Commit**

```bash
git add renderer/audio.js
git commit -m "soundis: add AudioSourceManager for mic/system audio capture and switching"
```

---

### Task 4: Electron Main Process

**Files:**
- Create: `main.js`

**Interfaces:**
- Produces: a registered `session.defaultSession.setDisplayMediaRequestHandler` that resolves `getDisplayMedia({video:true, audio:true})` calls from the renderer with `audio: 'loopback'` — this is what makes `AudioSourceManager.useSystemAudio()` (Task 3) work at runtime.
- Consumes: `renderer/index.html` (loaded via `loadFile`; created in Task 5 — not required to exist yet for this task's own verification).

- [ ] **Step 1: Write `main.js`**

```js
const { app, BrowserWindow, desktopCapturer, session } = require('electron');
const path = require('node:path');

function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 960,
    height: 720,
    backgroundColor: '#0a0a0a',
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

app.whenReady().then(() => {
  session.defaultSession.setDisplayMediaRequestHandler(
    (request, callback) => {
      desktopCapturer
        .getSources({ types: ['screen'] })
        .then((sources) => {
          callback({ video: sources[0], audio: 'loopback' });
        })
        .catch((error) => {
          console.error('[main] Failed to resolve display media sources:', error);
          callback({ video: null, audio: null });
        });
    },
    { useSystemPicker: true }
  );

  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
```

- [ ] **Step 2: Syntax-check the file**

Run: `node --check main.js`
Expected: no output, exit code 0.

- [ ] **Step 3: Commit**

```bash
git add main.js
git commit -m "soundis: add Electron main process with native system-audio loopback"
```

---

### Task 5: UI Shell

**Files:**
- Create: `renderer/index.html`
- Create: `renderer/style.css`

**Interfaces:**
- Produces DOM elements consumed by `renderer.js` (Task 7): `#canvas-container`, `#status`, `#btn-mic`, `#btn-system`.

- [ ] **Step 1: Write `renderer/index.html`**

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self'" />
  <title>soundis</title>
  <link rel="stylesheet" href="style.css" />
</head>
<body>
  <div id="canvas-container"></div>
  <div id="status" class="status">READY</div>
  <div class="controls">
    <button id="btn-mic" class="toggle-btn" type="button">MIC</button>
    <button id="btn-system" class="toggle-btn" type="button">SYSTEM</button>
  </div>
  <script src="renderer.js"></script>
</body>
</html>
```

- [ ] **Step 2: Write `renderer/style.css`**

```css
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html, body {
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: #0a0a0a;
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  color: #e0a458;
}

#canvas-container {
  position: fixed;
  inset: 0;
}

#canvas-container canvas {
  display: block;
}

.status {
  position: fixed;
  top: 16px;
  left: 16px;
  font-size: 12px;
  letter-spacing: 0.05em;
  opacity: 0.7;
  pointer-events: none;
}

.controls {
  position: fixed;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 12px;
}

.toggle-btn {
  background: #1a1a1a;
  border: 1px solid #3a3a3a;
  color: #e0a458;
  font-family: inherit;
  font-size: 12px;
  letter-spacing: 0.1em;
  padding: 10px 20px;
  cursor: pointer;
  border-radius: 2px;
  transition: border-color 0.15s ease, color 0.15s ease, background 0.15s ease;
}

.toggle-btn:hover {
  border-color: #e0a458;
}

.toggle-btn.active {
  background: #e0a458;
  color: #0a0a0a;
}
```

- [ ] **Step 3: Verify the required element ids are present**

Run: `grep -o 'id="[a-z-]*"' renderer/index.html`
Expected:
```
id="canvas-container"
id="status"
id="btn-mic"
id="btn-system"
```

- [ ] **Step 4: Commit**

```bash
git add renderer/index.html renderer/style.css
git commit -m "soundis: add dark mixing-console UI shell"
```

---

### Task 6: Three.js Particle Ring Visualizer

**Files:**
- Create: `renderer/visualizer.js`

**Interfaces:**
- Consumes: a DOM container element; the `three` package.
- Produces: `createVisualizer(container: HTMLElement) -> { update({ bass: number, mid: number, treble: number }): void }` — each value is 0–255. Consumed by `renderer.js` (Task 7).

- [ ] **Step 1: Write `renderer/visualizer.js`**

```js
const THREE = require('three');

const AMBER_HEX = 0xe0a458;
const BACKGROUND_HEX = 0x0a0a0a;
const PARTICLE_COUNT = 200;
const BASE_RADIUS = 2;

function createVisualizer(container) {
  const amber = new THREE.Color(AMBER_HEX);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(BACKGROUND_HEX);

  const camera = new THREE.PerspectiveCamera(
    60,
    container.clientWidth / container.clientHeight,
    0.1,
    100
  );
  camera.position.z = 6;

  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(window.devicePixelRatio);
  renderer.setSize(container.clientWidth, container.clientHeight);
  container.appendChild(renderer.domElement);

  const group = new THREE.Group();
  group.rotation.x = 0.4;
  scene.add(group);

  const basePositions = new Float32Array(PARTICLE_COUNT * 3);
  const positions = new Float32Array(PARTICLE_COUNT * 3);
  const colors = new Float32Array(PARTICLE_COUNT * 3);

  for (let i = 0; i < PARTICLE_COUNT; i++) {
    const angle = (i / PARTICLE_COUNT) * Math.PI * 2;
    const x = Math.cos(angle) * BASE_RADIUS;
    const y = Math.sin(angle) * BASE_RADIUS;

    basePositions[i * 3] = x;
    basePositions[i * 3 + 1] = y;
    basePositions[i * 3 + 2] = 0;

    positions[i * 3] = x;
    positions[i * 3 + 1] = y;
    positions[i * 3 + 2] = 0;

    colors[i * 3] = amber.r;
    colors[i * 3 + 1] = amber.g;
    colors[i * 3 + 2] = amber.b;
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));

  const material = new THREE.PointsMaterial({ size: 0.08, vertexColors: true });
  const points = new THREE.Points(geometry, material);
  group.add(points);

  function update({ bass, mid, treble }) {
    const bassNorm = bass / 255;
    const midNorm = mid / 255;
    const trebleNorm = treble / 255;

    const radiusScale = 1 + bassNorm * 0.6;
    group.rotation.z += 0.01 + midNorm * 0.08;

    const posAttr = geometry.attributes.position;
    const colorAttr = geometry.attributes.color;
    const brightness = 0.6 + trebleNorm * 0.4;
    const jitterAmount = trebleNorm * 0.15;

    for (let i = 0; i < PARTICLE_COUNT; i++) {
      const bx = basePositions[i * 3];
      const by = basePositions[i * 3 + 1];
      const jitterX = (Math.random() - 0.5) * jitterAmount;
      const jitterY = (Math.random() - 0.5) * jitterAmount;

      posAttr.array[i * 3] = bx * radiusScale + jitterX;
      posAttr.array[i * 3 + 1] = by * radiusScale + jitterY;

      colorAttr.array[i * 3] = amber.r * brightness;
      colorAttr.array[i * 3 + 1] = amber.g * brightness;
      colorAttr.array[i * 3 + 2] = amber.b * brightness;
    }

    posAttr.needsUpdate = true;
    colorAttr.needsUpdate = true;

    renderer.render(scene, camera);
  }

  function handleResize() {
    camera.aspect = container.clientWidth / container.clientHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(container.clientWidth, container.clientHeight);
  }

  window.addEventListener('resize', handleResize);

  return { update };
}

module.exports = { createVisualizer };
```

- [ ] **Step 2: Syntax-check the file**

Run: `node --check renderer/visualizer.js`
Expected: no output, exit code 0. (`window`/DOM APIs are only referenced inside function bodies, so this parses fine in plain Node even though it needs a browser to execute.)

- [ ] **Step 3: Commit**

```bash
git add renderer/visualizer.js
git commit -m "soundis: add Three.js particle ring visualizer with 3-band mapping"
```

---

### Task 7: Renderer Entry Point

**Files:**
- Create: `renderer/renderer.js`

**Interfaces:**
- Consumes: `AudioSourceManager` from `./audio.js` (Task 3), `createVisualizer` from `./visualizer.js` (Task 6), DOM ids from `renderer/index.html` (Task 5).
- Produces: nothing (leaf entry point, loaded via `<script src="renderer.js">`).

- [ ] **Step 1: Write `renderer/renderer.js`**

```js
const { AudioSourceManager } = require('./audio.js');
const { createVisualizer } = require('./visualizer.js');

const manager = new AudioSourceManager({ fftSize: 512 });
const visualizer = createVisualizer(document.getElementById('canvas-container'));

const statusEl = document.getElementById('status');
const micBtn = document.getElementById('btn-mic');
const systemBtn = document.getElementById('btn-system');

function setStatus(text) {
  statusEl.textContent = text;
}

function setActiveButton(source) {
  micBtn.classList.toggle('active', source === 'mic');
  systemBtn.classList.toggle('active', source === 'system');
}

micBtn.addEventListener('click', async () => {
  setStatus('MIC 연결 중...');
  try {
    await manager.useMicrophone();
    setActiveButton('mic');
    setStatus('MIC ACTIVE');
  } catch (error) {
    console.error('[renderer] Microphone capture failed:', error);
    setActiveButton(null);
    setStatus('마이크 접근이 거부됐습니다. 시스템 설정에서 허용해주세요.');
  }
});

systemBtn.addEventListener('click', async () => {
  setStatus('SYSTEM AUDIO 연결 중...');
  try {
    await manager.useSystemAudio();
    setActiveButton('system');
    setStatus('SYSTEM AUDIO ACTIVE');
  } catch (error) {
    console.error('[renderer] System audio capture failed:', error);
    setActiveButton(null);
    setStatus('시스템 오디오 캡처에 실패했습니다. 콘솔을 확인해주세요.');
  }
});

function animate() {
  requestAnimationFrame(animate);
  visualizer.update(manager.getBandEnergies());
}

setStatus('READY — MIC 또는 SYSTEM을 선택하세요');
animate();
```

- [ ] **Step 2: Syntax-check the file**

Run: `node --check renderer/renderer.js`
Expected: no output, exit code 0.

- [ ] **Step 3: Commit**

```bash
git add renderer/renderer.js
git commit -m "soundis: wire renderer entry point to audio manager and visualizer"
```

---

### Task 8: macOS Packaging (electron-builder)

**Files:**
- Modify: `package.json` (add top-level `build` field)

**Interfaces:**
- Produces: a packaged `Soundis.app` under `dist/` with `NSAudioCaptureUsageDescription` / `NSMicrophoneUsageDescription` set in its `Info.plist`. This is what makes system-audio capture (Task 3/4) actually work — the plain `electron .` dev binary lacks these keys on macOS 14.2+.

- [ ] **Step 1: Add the `build` field to `package.json`**

Add this top-level key (sibling of `"scripts"`, `"dependencies"`, etc.):

```json
  "build": {
    "appId": "com.soundis.app",
    "productName": "Soundis",
    "directories": {
      "output": "dist"
    },
    "files": [
      "main.js",
      "renderer/**/*"
    ],
    "mac": {
      "category": "public.app-category.music",
      "identity": null,
      "extendInfo": {
        "NSAudioCaptureUsageDescription": "Soundis captures system audio to drive the visualizer.",
        "NSMicrophoneUsageDescription": "Soundis captures microphone audio to drive the visualizer."
      }
    }
  }
```

`identity: null` skips code-signing identity lookup — this app is built and run locally, never distributed, so ad-hoc/no signing is sufficient (no Gatekeeper quarantine issue since there's no download step).

- [ ] **Step 2: Run the build**

Run: `npm run build`
Expected: completes with no errors, creates `dist/mac-arm64/Soundis.app` (or `dist/mac/Soundis.app` on Intel).

- [ ] **Step 3: Verify the Info.plist keys are present**

Run:
```bash
find dist -maxdepth 2 -name "Soundis.app" -exec /usr/libexec/PlistBuddy -c "Print :NSAudioCaptureUsageDescription" {}/Contents/Info.plist \;
```
Expected: prints `Soundis captures system audio to drive the visualizer.`

- [ ] **Step 4: Commit**

```bash
git add package.json
git commit -m "soundis: add electron-builder mac packaging with audio-capture Info.plist keys"
```

---

### Task 9: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

```markdown
# soundis

macOS(Sequoia 15+)용 오디오 반응형 비주얼라이저. 마이크 또는 시스템에서 재생 중인
소리(유튜브, 스포티파이 등)를 실시간으로 캡처해 Three.js 파티클 링으로 시각화합니다.

## 개발 모드로 실행

\`\`\`bash
npm install
npm start
\`\`\`

마이크 모드는 개발 모드(`npm start`)에서도 정상 동작합니다. **시스템 오디오 모드는
개발 모드에서 무음으로 실패할 수 있습니다** — macOS 14.2+는 `desktopCapturer` 오디오
캡처에 `NSAudioCaptureUsageDescription` Info.plist 키를 요구하는데, `electron .`이
쓰는 Electron 기본 바이너리에는 이 키가 없기 때문입니다. 시스템 오디오는 아래 패키지
빌드로 테스트하세요.

## 패키지 빌드 (시스템 오디오 테스트용)

\`\`\`bash
npm run build
open dist/mac-arm64/Soundis.app   # Apple Silicon. Intel이면 dist/mac/Soundis.app
\`\`\`

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
\`\`\`

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "soundis: add README with setup, permissions, and design notes"
```

---

### Task 10: End-to-End Verification

**Files:** none (verification only)

- [ ] **Step 1: Automated smoke check — dev mode launches without errors**

Run:
```bash
STARTUP_OUTPUT=$(timeout 8 npm start 2>&1; true)
echo "$STARTUP_OUTPUT" | grep -iE "error|uncaught|exception" || echo "NO ERRORS FOUND"
```
Expected: `NO ERRORS FOUND` (Electron security-warning notices about `nodeIntegration`/`contextIsolation` in dev mode are expected and fine — only fail this check on real stack traces).

- [ ] **Step 2: Automated smoke check — packaged app Info.plist (already done in Task 8, re-verify here as a full-pipeline check)**

Run:
```bash
find dist -maxdepth 2 -name "Soundis.app" -exec /usr/libexec/PlistBuddy -c "Print :NSAudioCaptureUsageDescription" {}/Contents/Info.plist \; -exec /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" {}/Contents/Info.plist \;
```
Expected: both description strings print with no errors.

- [ ] **Step 3: Manual check — this step requires a human at the keyboard, not an agent**

The remaining checks need someone to see the visualizer respond to real audio and click
through permission dialogs — an agent cannot claim these as verified. Ask the user to:

1. Run `npm start`, confirm the window shows a dark background, an amber particle ring,
   and MIC/SYSTEM buttons at the bottom.
2. Click **MIC**, grant the permission prompt, play music near the mic, and confirm the
   ring's radius pulses with bass, rotation speeds up with mids, and particle brightness/
   jitter responds to treble.
3. Run the packaged app (`open dist/mac-arm64/Soundis.app`), play audio via YouTube/Spotify,
   click **SYSTEM**, and confirm the same reactivity — this is the path that needs the
   packaged build, not dev mode.
4. Toggle between MIC and SYSTEM a few times and confirm there's no crash, no long silence/
   freeze, and the status text updates correctly each time.

Do not report this plan as fully complete until the user confirms step 3 (system audio
via the packaged app) — that is the one path Task 1–9's automated checks cannot cover.
