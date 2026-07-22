const { AudioSourceManager } = require('./audio.js');
const { createVisualizer } = require('./visualizer.js');

const manager = new AudioSourceManager({ fftSize: 512 });
const visualizer = createVisualizer(document.getElementById('canvas-container'));

const statusEl = document.getElementById('status');
const micBtn = document.getElementById('btn-mic');
const systemBtn = document.getElementById('btn-system');

let activeSource = null;

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
    activeSource = 'mic';
    setActiveButton('mic');
    setStatus('MIC ACTIVE');
  } catch (error) {
    console.error('[renderer] Microphone capture failed:', error);
    setActiveButton(activeSource);
    setStatus('마이크 접근이 거부됐습니다. 시스템 설정에서 허용해주세요.');
  }
});

systemBtn.addEventListener('click', async () => {
  setStatus('SYSTEM AUDIO 연결 중...');
  try {
    await manager.useSystemAudio();
    activeSource = 'system';
    setActiveButton('system');
    setStatus('SYSTEM AUDIO ACTIVE');
  } catch (error) {
    console.error('[renderer] System audio capture failed:', error);
    setActiveButton(activeSource);
    setStatus('시스템 오디오 캡처에 실패했습니다. 콘솔을 확인해주세요.');
  }
});

function animate() {
  requestAnimationFrame(animate);
  visualizer.update(manager.getBandEnergies());
}

setStatus('READY — MIC 또는 SYSTEM을 선택하세요');
animate();
