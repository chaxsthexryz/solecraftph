// node audio.mjs out/score.wav — 15 s score + SFX at 120 BPM, synthesized, deterministic.
// Cue times match the picture (index.html): taps, wipes, cards, logo stamps.
import { writeFileSync } from 'node:fs';
const SR = 48000, DUR = 15.6, BEAT = 0.5, N = Math.ceil(DUR * SR);
const L = new Float32Array(N), R = new Float32Array(N);
let seed = 42; const noise = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 2147483648 - 1;
const hz = (m) => 440 * 2 ** ((m - 69) / 12);
function add(t0, len, fn, gain = 1, pan = 0) {
  const s0 = Math.floor(t0 * SR), gl = gain * Math.min(1, 1 - pan), gr = gain * Math.min(1, 1 + pan);
  for (let i = 0; i < len * SR && s0 + i < N; i++) { if (s0 + i < 0) continue; const v = fn(i / SR); L[s0 + i] += v * gl; R[s0 + i] += v * gr; }
}
// ---- voices
const kick = (t) => Math.sin(2 * Math.PI * (48 * t + 90 * (1 - Math.exp(-t * 28)) / 28)) * Math.exp(-t * 7);
const hat = (t) => noise() * Math.exp(-t * 60) * 0.5;
const clap = (t) => noise() * (Math.exp(-t * 25) + 0.6 * Math.exp(-Math.abs(t - 0.012) * 300)) * 0.6;
const pluck = (f) => (t) => (Math.sin(2 * Math.PI * f * t) + 0.35 * Math.sin(4 * Math.PI * f * t) + 0.12 * Math.sin(6 * Math.PI * f * t)) * Math.exp(-t * 9) * Math.min(1, t * 400);
const bass = (f, len) => (t) => Math.tanh(2.2 * (Math.sin(2 * Math.PI * f * t) + 0.3 * Math.sin(4 * Math.PI * f * t))) * Math.min(1, t * 300, (len - t) * 60) * 0.5;
const piano = (f) => (t) => [1, 2, 3, 4].reduce((a, h) => a + Math.sin(2 * Math.PI * f * h * t * (1 + 0.0004 * h)) * Math.exp(-t * (1.6 + h)) / h ** 1.4, 0) * Math.min(1, t * 500);
const click = (t) => Math.sin(2 * Math.PI * 2100 * t) * Math.exp(-t * 120) * 0.7 + noise() * Math.exp(-t * 400) * 0.3;
const pop = (t) => Math.sin(2 * Math.PI * (500 + 1200 * t) * t) * Math.exp(-t * 26) * 0.55;
const whoosh = (len) => { let lp = 0; return (t) => { const x = t / len; const c = 0.02 + 0.25 * Math.sin(Math.PI * x); lp += c * (noise() - lp); return lp * Math.sin(Math.PI * x) ** 2 * 2.2; }; };
const tick = (t) => Math.sin(2 * Math.PI * 3200 * t) * Math.exp(-t * 200) * 0.5;
const thump = (t) => Math.sin(2 * Math.PI * (40 * t + 120 * (1 - Math.exp(-t * 18)) / 18)) * Math.exp(-t * 4.5) * 1.1;

// ---- harmony: A minor → F → C → G, one chord per bar (2 s). MIDI roots.
const BARS = [[57, [57, 60, 64]], [53, [53, 57, 60]], [48, [55, 60, 64]], [55, [55, 59, 62]]];
const chordAt = (t) => BARS[Math.floor(t / 2) % 4];

// Intro (0–2 s): tension. Low piano + kicks on the two text slams, ticks on each size slash.
add(0, 2.2, piano(hz(45)), 0.5); add(0, 2.2, piano(hz(57)), 0.25); add(0, 2.2, piano(hz(64)), 0.18);
add(0.0, 0.6, kick, 0.9); add(1.0, 0.6, kick, 0.9); add(1.0, 2, piano(hz(60)), 0.2);
for (const t of [1.15, 1.4, 1.65]) add(t, 0.1, tick, 0.8, 0.2);
// Groove (2–13.5 s)
for (let b = 4; b < 27; b++) {
  const t = b * BEAT, [root, ch] = chordAt(t);
  add(t, 0.6, kick, 0.95);
  add(t + BEAT / 2, 0.08, hat, 0.35, 0.3); add(t + BEAT / 4, 0.05, hat, 0.12, -0.3); add(t + 3 * BEAT / 4, 0.05, hat, 0.12, -0.3);
  if (b % 2 === 1) add(t, 0.3, clap, 0.45, -0.1);
  add(t, 0.24, bass(hz(root - 12), 0.24), 0.55); add(t + 0.25, 0.22, bass(hz(root - 12), 0.22), 0.45);
  for (let k = 0; k < 4; k++) { const n = ch[(b * 4 + k) % 3] + (k === 3 ? 12 : 0); add(t + k * BEAT / 4, 0.4, pluck(hz(n + 12)), 0.12, k % 2 ? 0.35 : -0.35); }
  if (b % 4 === 0) for (const n of ch) add(t, 2, piano(hz(n)), 0.13);
}
// Finale (13.5 s): impact on the logo, ring out on the tonic.
add(13.5, 1.6, thump, 1.0); add(13.5, 0.4, clap, 0.5);
for (const n of [45, 57, 60, 64, 69]) add(13.5, 2.1, piano(hz(n)), 0.22);
add(14.2, 0.4, pluck(hz(76)), 0.12); add(14.35, 0.4, pluck(hz(81)), 0.1);

// ---- SFX on picture cues
for (const [t, len] of [[1.75, 0.5], [3.85, 0.45], [6.3, 0.35], [6.9, 0.35], [9.35, 0.4], [11.85, 0.5], [13.2, 0.55]]) add(t, len, whoosh(len), 0.5, 0.15);
add(2.15, 1.2, thump, 0.55);                                   // logo stamp
for (const t of [4.75, 5.75, 7.75, 9.0]) add(t, 0.06, click, 0.55, 0.25);   // taps
for (const t of [10.0, 10.5, 11.0]) add(t, 0.25, pop, 0.5, 0.4);            // notification cards
add(5.87, 0.25, pop, 0.3);                                   // "Added to Bag" toast

// ---- write 16-bit stereo WAV (peak-normalised; loudness set by ffmpeg)
let peak = 0; for (let i = 0; i < N; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
const gn = 0.9 / peak, b = Buffer.alloc(44 + N * 4);
b.write('RIFF', 0); b.writeUInt32LE(36 + N * 4, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20);
b.writeUInt16LE(2, 22); b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 4, 28); b.writeUInt16LE(4, 32); b.writeUInt16LE(16, 34);
b.write('data', 36); b.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) { b.writeInt16LE(Math.round(L[i] * gn * 32767), 44 + i * 4); b.writeInt16LE(Math.round(R[i] * gn * 32767), 46 + i * 4); }
writeFileSync(process.argv[2] || 'out/score.wav', b);
