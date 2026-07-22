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
