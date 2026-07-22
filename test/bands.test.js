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
