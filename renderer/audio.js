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
