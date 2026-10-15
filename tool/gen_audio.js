// Synthesises every sound in the game into assets/audio as 16-bit mono WAV.
// Run from the project root: node tool/gen_audio.js
const fs = require('fs');
const path = require('path');

const RATE = 22050;
const OUT = path.join(__dirname, '..', 'assets', 'audio');
fs.mkdirSync(OUT, { recursive: true });

// Deterministic noise so reruns give identical files.
let seed = 4242;
const noise = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x3fffffff - 1;
};

function write(name, samples, peak = 0.8) {
  let max = 0;
  for (const s of samples) max = Math.max(max, Math.abs(s));
  const gain = max > 0 ? peak / max : 1;
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((s, i) =>
    data.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(s * gain * 32767))), i * 2));
  const head = Buffer.alloc(44);
  head.write('RIFF', 0);
  head.writeUInt32LE(36 + data.length, 4);
  head.write('WAVEfmt ', 8);
  head.writeUInt32LE(16, 16);
  head.writeUInt16LE(1, 20);
  head.writeUInt16LE(1, 22);
  head.writeUInt32LE(RATE, 24);
  head.writeUInt32LE(RATE * 2, 28);
  head.writeUInt16LE(2, 32);
  head.writeUInt16LE(16, 34);
  head.write('data', 36);
  head.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(OUT, name), Buffer.concat([head, data]));
  console.log(name, (samples.length / RATE).toFixed(2) + 's');
}

const buf = (seconds) => new Float64Array(Math.round(seconds * RATE));
const T = (i) => i / RATE;

function lowpass(x, cutoff) {
  const a = 1 - Math.exp((-2 * Math.PI * cutoff) / RATE);
  let y = 0;
  for (let i = 0; i < x.length; i++) {
    y += a * (x[i] - y);
    x[i] = y;
  }
  return x;
}

function highpass(x, cutoff) {
  const lp = lowpass(Float64Array.from(x), cutoff);
  for (let i = 0; i < x.length; i++) x[i] -= lp[i];
  return x;
}

// Adds a sine sweeping from f0 to f1 with an exponential decay.
function tone(x, start, dur, f0, f1, amp, decay = 6, wave = Math.sin) {
  const s0 = Math.round(start * RATE), n = Math.round(dur * RATE);
  let ph = 0;
  for (let i = 0; i < n && s0 + i < x.length; i++) {
    const k = i / n;
    const f = f0 * Math.pow(f1 / f0, k);
    ph += (2 * Math.PI * f) / RATE;
    const env = Math.min(1, i / (RATE * 0.004)) * Math.exp(-decay * k);
    x[s0 + i] += wave(ph) * amp * env;
  }
}

const saw = (p) => ((p / Math.PI) % 2) - 1;

// Noise shaped by an envelope function of 0..1.
function noiseBurst(x, start, dur, amp, env) {
  const s0 = Math.round(start * RATE), n = Math.round(dur * RATE);
  for (let i = 0; i < n && s0 + i < x.length; i++) x[s0 + i] += noise() * amp * env(i / n);
}

// Karplus-Strong plucked string, added into x.
function pluck(x, start, freq, amp, dur = 1.6, bright = 0.5) {
  const n = Math.max(2, Math.round(RATE / freq));
  const line = new Float64Array(n);
  for (let i = 0; i < n; i++) line[i] = noise() * (0.5 + bright * 0.5);
  const s0 = Math.round(start * RATE), len = Math.round(dur * RATE);
  let idx = 0, prev = 0;
  for (let i = 0; i < len && s0 + i < x.length; i++) {
    const v = line[idx];
    const next = line[(idx + 1) % n];
    line[idx] = 0.996 * (0.5 * (v + next));
    // A slight pitch bend down at the start, like a guzheng press.
    x[s0 + i] += (v * 0.8 + prev * 0.2) * amp * Math.min(1, i / 30);
    prev = v;
    idx = (idx + 1) % n;
  }
}

// Gong: inharmonic partials with slow decay and a little shimmer.
function gong(x, start, base, amp, dur) {
  const parts = [1, 1.48, 1.92, 2.56, 3.2, 4.1];
  parts.forEach((p, k) =>
    tone(x, start, dur, base * p, base * p * 0.995, amp / (k + 1.2), 3 + k * 1.5));
  noiseBurst(x, start, 0.05, amp * 0.4, (k) => 1 - k);
}

// --------------------------------------------------------------- effects

function swing() {
  const x = buf(0.22);
  noiseBurst(x, 0, 0.22, 1, (k) => Math.sin(Math.PI * k) ** 2);
  return highpass(lowpass(x, 2600), 400);
}

function hit() {
  const x = buf(0.16);
  tone(x, 0, 0.14, 160, 60, 1, 9);
  noiseBurst(x, 0, 0.05, 0.8, (k) => 1 - k);
  return lowpass(x, 3000);
}

function shoot() {
  const x = buf(0.16);
  tone(x, 0, 0.14, 1800, 900, 0.5, 5);
  noiseBurst(x, 0, 0.14, 0.5, (k) => (1 - k) * Math.min(1, k * 8));
  return highpass(x, 600);
}

function slash() {
  const x = buf(0.42);
  noiseBurst(x, 0, 0.3, 1, (k) => Math.sin(Math.PI * k) ** 1.5);
  lowpass(x, 3500);
  [1320, 1980, 2640].forEach((f) => tone(x, 0.05, 0.37, f, f, 0.12, 7));
  return x;
}

function magic() {
  const x = buf(0.8);
  const notes = [784, 880, 1047, 1175, 1568];
  notes.forEach((f, i) => tone(x, i * 0.06, 0.55, f, f, 0.35, 5));
  noiseBurst(x, 0, 0.6, 0.06, (k) => 1 - k);
  return x;
}

function boom() {
  const x = buf(0.9);
  noiseBurst(x, 0, 0.8, 1, (k) => Math.exp(-5 * k));
  lowpass(x, 500);
  tone(x, 0, 0.7, 90, 35, 1.2, 4);
  return x;
}

function ice() {
  const x = buf(0.6);
  [2093, 2637, 3136, 2349, 3520].forEach((f, i) => tone(x, i * 0.045, 0.35, f, f * 1.01, 0.3, 9));
  noiseBurst(x, 0, 0.12, 0.3, (k) => 1 - k);
  return highpass(x, 800);
}

function poison() {
  const x = buf(0.55);
  for (let i = 0; i < 9; i++) {
    const f = 220 + (noise() + 1) * 260;
    tone(x, i * 0.05 + Math.abs(noise()) * 0.02, 0.09, f, f * 1.8, 0.4, 4);
  }
  return lowpass(x, 1800);
}

function fire() {
  const x = buf(0.6);
  noiseBurst(x, 0, 0.6, 1, (k) => Math.min(1, k * 10) * (1 - k));
  lowpass(x, 1400);
  // Crackles.
  for (let i = 0; i < 18; i++) {
    const t = Math.abs(noise()) * 0.5;
    noiseBurst(x, t, 0.006, 1.2, (k) => 1 - k);
  }
  tone(x, 0, 0.5, 120, 70, 0.5, 4);
  return x;
}

function dash() {
  const x = buf(0.35);
  noiseBurst(x, 0, 0.35, 1, (k) => Math.sin(Math.PI * k));
  lowpass(x, 2200);
  tone(x, 0, 0.3, 200, 500, 0.4, 2, saw);
  return x;
}

function die() {
  const x = buf(0.4);
  tone(x, 0, 0.36, 260, 90, 0.8, 3, saw);
  noiseBurst(x, 0, 0.25, 0.4, (k) => 1 - k);
  return lowpass(x, 1200);
}

function bossDie() {
  const x = buf(1.4);
  tone(x, 0, 1.0, 180, 45, 1, 2.5, saw);
  noiseBurst(x, 0.05, 1.2, 0.8, (k) => Math.exp(-3 * k));
  lowpass(x, 700);
  gong(x, 0.1, 110, 0.6, 1.25);
  return x;
}

function potion() {
  const x = buf(0.3);
  tone(x, 0, 0.1, 400, 700, 0.8, 3);
  tone(x, 0.11, 0.12, 500, 900, 0.8, 3);
  return lowpass(x, 2500);
}

function coin() {
  const x = buf(0.25);
  tone(x, 0, 0.1, 1976, 1976, 0.6, 5);
  tone(x, 0.07, 0.18, 2637, 2637, 0.6, 5);
  return x;
}

function loot() {
  const x = buf(0.5);
  [1047, 1319, 1568, 2093].forEach((f, i) => tone(x, i * 0.06, 0.3, f, f, 0.4, 6));
  return x;
}

function heroDie() {
  const x = buf(1.1);
  [440, 392, 330, 262].forEach((f, i) => pluck(x, i * 0.18, f, 0.8, 0.9));
  gong(x, 0, 98, 0.5, 1.05);
  return x;
}

function levelup() {
  const x = buf(1.4);
  // Pentatonic run up, then a bright gong.
  [392, 440, 523, 587, 659, 784].forEach((f, i) => pluck(x, i * 0.07, f, 0.8, 1.2, 0.8));
  gong(x, 0.42, 330, 0.7, 0.95);
  return x;
}

function quest() {
  const x = buf(1.0);
  [659, 784, 988].forEach((f, i) => pluck(x, i * 0.1, f, 0.9, 0.9, 0.9));
  tone(x, 0.2, 0.8, 1319, 1319, 0.2, 4);
  return x;
}

function click() {
  const x = buf(0.06);
  tone(x, 0, 0.05, 1400, 900, 0.6, 10);
  return x;
}

function gongHit() {
  const x = buf(1.6);
  gong(x, 0, 140, 1, 1.55);
  return lowpass(x, 4000);
}

// --------------------------------------------------------------- theme

// A slow pentatonic guzheng-style tune over a drone, ~38 seconds, built so
// the end runs back into the start.
function theme() {
  const bpm = 76;
  const beat = 60 / bpm;
  const bars = 12;
  const x = buf(bars * 4 * beat);
  // G pentatonic: G A B D E across octaves.
  const scale = [196, 220, 247, 294, 330, 392, 440, 494, 587, 659, 784];
  const phrase = [
    [5, 1], [7, 0.5], [8, 0.5], [9, 1], [8, 1],
    [7, 1.5], [5, 0.5], [6, 2],
    [4, 1], [5, 0.5], [6, 0.5], [7, 1], [5, 1],
    [4, 1.5], [3, 0.5], [2, 2],
    [5, 1], [7, 1], [9, 1], [10, 1],
    [9, 1.5], [8, 0.5], [7, 2],
    [6, 1], [5, 1], [4, 0.5], [3, 0.5], [2, 1],
    [3, 1], [1, 1], [0, 2],
  ];
  let t = 0;
  const total = x.length / RATE;
  while (t < total - 0.01) {
    for (const [n, d] of phrase) {
      if (t >= total - 0.01) break;
      pluck(x, t, scale[n], 0.55, Math.min(2.4, total - t), 0.55);
      // A soft lower octave on long notes.
      if (d >= 2) pluck(x, t + 0.02, scale[n] / 2, 0.25, Math.min(2.6, total - t), 0.3);
      t += d * beat;
    }
  }
  // Drone on G and D, breathing slowly; equal at both ends for the loop.
  for (let i = 0; i < x.length; i++) {
    const s = T(i);
    const breathe = 0.6 + 0.4 * Math.sin((2 * Math.PI * s) / (total / 3));
    x[i] += (Math.sin(2 * Math.PI * 98 * s) * 0.08 + Math.sin(2 * Math.PI * 147 * s) * 0.05) * breathe;
  }
  // Woodblock on each bar.
  for (let b = 0; b < bars; b++) {
    const s0 = b * 4 * beat;
    tone(x, s0, 0.08, 900, 700, 0.25, 12);
    tone(x, s0 + 2 * beat, 0.06, 1100, 800, 0.12, 12);
  }
  // Fade the seam a hair so the loop does not click.
  const f = Math.round(0.02 * RATE);
  for (let i = 0; i < f; i++) {
    x[i] *= i / f;
    x[x.length - 1 - i] *= i / f;
  }
  return lowpass(x, 5000);
}

write('swing.wav', swing(), 0.6);
write('hit.wav', hit(), 0.8);
write('shoot.wav', shoot(), 0.5);
write('slash.wav', slash(), 0.75);
write('magic.wav', magic(), 0.6);
write('boom.wav', boom(), 0.9);
write('ice.wav', ice(), 0.6);
write('poison.wav', poison(), 0.6);
write('fire.wav', fire(), 0.8);
write('dash.wav', dash(), 0.7);
write('die.wav', die(), 0.6);
write('bossdie.wav', bossDie(), 0.9);
write('potion.wav', potion(), 0.6);
write('coin.wav', coin(), 0.45);
write('loot.wav', loot(), 0.55);
write('herodie.wav', heroDie(), 0.8);
write('levelup.wav', levelup(), 0.85);
write('quest.wav', quest(), 0.8);
write('click.wav', click(), 0.5);
write('gong.wav', gongHit(), 0.8);
write('theme.wav', theme(), 0.7);
