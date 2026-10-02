// node film3d/audio.mjs out/b3d/score.wav — 20 s score + SFX for the Blender cut, 96 BPM (beat 0.625 s, bar 2.5 s).
// Synthesized and seeded, so it is identical every run. Cue times match film3d/build_scene.py (frame / 30).
import { writeFileSync } from 'node:fs';
const SR = 48000, DUR = 20.5, B = 0.625, N = Math.ceil(DUR * SR);
const L = new Float32Array(N), R = new Float32Array(N);
let seed = 7; const noise = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 2147483648 - 1;
const hz = (m) => 440 * 2 ** ((m - 69) / 12);
function add(t0, len, fn, gain = 1, pan = 0) {
  const s0 = Math.floor(t0 * SR), gl = gain * Math.min(1, 1 - pan), gr = gain * Math.min(1, 1 + pan);
  for (let i = 0; i < len * SR; i++) { const j = s0 + i; if (j < 0 || j >= N) continue; const v = fn(i / SR); L[j] += v * gl; R[j] += v * gr; }
}
// voices
const kick = (t) => Math.sin(2 * Math.PI * (46 * t + 100 * (1 - Math.exp(-t * 30)) / 30)) * Math.exp(-t * 6.5) + noise() * Math.exp(-t * 300) * 0.15;
const boom = (t) => Math.sin(2 * Math.PI * (34 * t + 90 * (1 - Math.exp(-t * 12)) / 12)) * Math.exp(-t * 2.6);
const snare = (t) => (noise() * 0.8 + Math.sin(2 * Math.PI * 190 * t) * 0.5) * Math.exp(-t * 18);
const clap = (t) => noise() * (Math.exp(-t * 22) + 0.5 * Math.exp(-Math.abs(t - 0.011) * 320) + 0.4 * Math.exp(-Math.abs(t - 0.022) * 320)) * 0.7;
const hat = (open) => (t) => { let v = noise(); return v * Math.exp(-t * (open ? 12 : 70)) * 0.45; };
const pluck = (f) => (t) => (Math.sin(2 * Math.PI * f * t) + 0.35 * Math.sin(4 * Math.PI * f * t) + 0.1 * Math.sin(6 * Math.PI * f * t)) * Math.exp(-t * 8) * Math.min(1, t * 400);
const bass = (f, len) => (t) => Math.tanh(2.4 * (Math.sin(2 * Math.PI * f * t) + 0.3 * Math.sin(4 * Math.PI * f * t))) * Math.min(1, t * 300, Math.max(0, len - t) * 50) * 0.5;
const piano = (f, dec = 1.5) => (t) => [1, 2, 3, 4, 5].reduce((a, h) => a + Math.sin(2 * Math.PI * f * h * t * (1 + 0.0003 * h * h)) * Math.exp(-t * (dec + h * 0.9)) / h ** 1.5, 0) * Math.min(1, t * 600);
const click = (t) => Math.sin(2 * Math.PI * 2100 * t) * Math.exp(-t * 120) * 0.7 + noise() * Math.exp(-t * 400) * 0.3;
const tick = (t) => Math.sin(2 * Math.PI * 3000 * t) * Math.exp(-t * 180) * 0.5;
const pop = (t) => Math.sin(2 * Math.PI * (480 + 1300 * t) * t) * Math.exp(-t * 24) * 0.55;
const tock = (t) => (Math.sin(2 * Math.PI * 160 * t) * Math.exp(-t * 30) + noise() * Math.exp(-t * 160) * 0.4) * 0.9;
const slash = (t) => noise() * Math.exp(-t * 35) * Math.min(1, t * 2000) * 0.8 + Math.sin(2 * Math.PI * (2400 - 3000 * t) * t) * Math.exp(-t * 40) * 0.3;
const whoosh = (len, bright = 0.25) => { let lp = 0; return (t) => { const x = t / len, c = 0.02 + bright * Math.sin(Math.PI * x); lp += c * (noise() - lp); return lp * Math.sin(Math.PI * x) ** 2 * 2.4; }; };
const riser = (len) => { let lp = 0; return (t) => { const x = t / len, c = 0.01 + 0.4 * x * x; lp += c * (noise() - lp); return lp * x ** 2 * 2.2 + Math.sin(2 * Math.PI * (200 + 600 * x * x) * t) * x ** 3 * 0.15; }; };
const down = (t) => Math.sin(2 * Math.PI * (420 * t - 120 * t * t)) * Math.exp(-t * 3) * 0.35;   // "sold out" droop

// harmony per bar (MIDI): Am, F, C, G, Am, F, (lineup) C→G, (end) Am
const BARS = [[45, [57, 60, 64]], [41, [57, 60, 65]], [48, [55, 60, 64]], [43, [55, 59, 62]], [45, [57, 60, 64]], [41, [57, 60, 65]], [48, [55, 60, 64]], [45, [57, 60, 64, 71]]];

// bar 1 (0–2.5): the hook
add(0, 2.4, boom, 0.9); add(0, 0.5, kick, 0.8);
for (const n of [33, 45, 57, 60, 64]) add(0, 2.4, piano(hz(n), 1.1), 0.16);
for (let i = 0; i < 6; i++) add(0.55 + i * 0.07, 0.08, tick, 0.35, -0.3 + i * 0.12);
add(0.9375, 0.5, pluck(hz(76)), 0.22);
add(1.25, 0.5, kick, 0.7);
for (const t of [1.5625, 1.875, 2.1875]) { add(t, 0.25, slash, 0.55, 0.25); add(t, 0.4, kick, 0.35); }
add(1.5625, 1.0, down, 0.8);
add(1.85, 0.65, riser(0.65), 0.55);
add(2.12, 0.5, whoosh(0.5, 0.35), 0.6, -0.2);

// bars 2–7 (2.5–17.5): the groove
for (let bar = 1; bar < 7; bar++) {
  const t0 = bar * 2.5, [root, ch] = BARS[bar], chorus = bar === 6;
  for (const n of ch) add(t0, 2.4, piano(hz(n), 1.4), 0.1);
  for (let b = 0; b < 4; b++) {
    const t = t0 + b * B;
    add(t, 0.5, kick, 0.95);
    if (b % 2 === 1) { add(t, 0.3, snare, 0.32, -0.05); add(t, 0.3, clap, chorus ? 0.55 : 0.4, 0.05); }
    for (let s = 0; s < 4; s++) add(t + s * B / 4, 0.1, hat(false), s === 2 ? 0.32 : 0.14, s % 2 ? 0.3 : -0.3);
    if (chorus) add(t + B / 2, 0.3, hat(true), 0.18, 0.2);
    // bass: root on the beat, octave on the "and", a 16th pickup before beat 4
    add(t, B * 0.45, bass(hz(root - 12), B * 0.45), 0.6);
    add(t + B / 2, B * 0.3, bass(hz(root), B * 0.3), 0.38);
    if (b === 2) add(t + 3 * B / 4, B * 0.22, bass(hz(root - 10), B * 0.22), 0.35);
    // arpeggio, sixteenths
    for (let s = 0; s < 4; s++) { const n = ch[(b * 4 + s) % ch.length] + 12 + (s === 3 ? 12 : 0); add(t + s * B / 4, 0.35, pluck(hz(n)), chorus ? 0.12 : 0.09, s % 2 ? 0.35 : -0.35); }
  }
}

// bar 8 (17.5–20): impact, then the tonic rings out
add(17.55, 2.4, boom, 1.0); add(17.55, 0.5, kick, 0.9); add(17.55, 0.4, clap, 0.5);
for (const n of [33, 45, 57, 60, 64, 71]) add(17.55, 2.45, piano(hz(n), 0.7), 0.17);
add(18.35, 0.5, pluck(hz(76)), 0.14, 0.2); add(18.5, 0.6, pluck(hz(81)), 0.12, -0.2); add(18.66, 0.9, pluck(hz(88)), 0.08);

// SFX on picture cues (frame numbers from build_scene.py, 30 fps)
const fr = (f) => f / 30;
add(0.0, 0.45, whoosh(0.45, 0.4), 0.5, 0.4);                                   // hero glides in
for (let i = 0; i < 6; i++) add(fr(22 + i * 2), 0.2, tock, 0.3, -0.3 + i * 0.12); // tiles land
for (const f of [47, 56, 66]) add(fr(f + 3), 0.3, whoosh(0.3, 0.3), 0.3, 0.2);  // tiles flip
for (const f of [88, 97, 106]) add(fr(f), 0.6, boom, 0.45);                    // letters land
add(fr(96), 0.8, whoosh(0.8, 0.2), 0.4, 0.3);                                  // phone rises
add(fr(150), 0.6, whoosh(0.6, 0.3), 0.45, -0.3); add(fr(156), 0.6, whoosh(0.6, 0.3), 0.45, 0.3);   // the phone unfolds
add(5.625, 0.08, tick, 0.4, 0.3);                                              // size 12 sold out
for (const t of [6.25, 6.875, 8.125, 9.375]) add(t, 0.06, click, 0.55, 0.25);  // taps
add(6.975, 0.25, pop, 0.3);                                                    // "Added to Bag"
for (const f of [228, 300]) add(fr(f), 0.55, whoosh(0.55, 0.18), 0.35, -0.2);  // finished screens sink
add(9.7, 0.3, whoosh(0.3, 0.15), 0.25, 0.2);                                   // Order Placed
for (const f of [319, 338, 356]) add(fr(f + 6), 0.25, pop, 0.5, 0.4);          // notifications
add(fr(378), 0.8, whoosh(0.8, 0.22), 0.4, 0.3); add(fr(400), 0.12, tock, 0.6); // laptop lid opens
add(fr(384), 0.7, whoosh(0.7, 0.2), 0.3, 0.5);                                  // phone rises beside it
for (let i = 0; i < 6; i++) add(fr(459 + i * 9 + 10), 0.2, tock, 0.45, -0.4 + i * 0.16);   // blocks land
add(17.1, 0.5, riser(0.5), 0.4); add(17.15, 0.5, whoosh(0.5, 0.35), 0.55);    // ink rises
add(fr(528), 0.8, whoosh(0.8, 0.25), 0.35); add(fr(542), 1.2, boom, 0.4);      // wordmark rises
add(17.95, 1.0, boom, 0.3);                                                    // logo stamp
add(18.45, 0.08, tick, 0.4);                                                   // URL

// master: gentle fade at the very end, peak-normalise (loudness is set by ffmpeg)
for (let i = 0; i < N; i++) { const t = i / SR, f = t > 19.3 ? Math.max(0, 1 - (t - 19.3) / 0.7) : 1; L[i] *= f; R[i] *= f; }
let peak = 0; for (let i = 0; i < N; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
const g = 0.9 / peak, b = Buffer.alloc(44 + N * 4);
b.write('RIFF', 0); b.writeUInt32LE(36 + N * 4, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20);
b.writeUInt16LE(2, 22); b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 4, 28); b.writeUInt16LE(4, 32); b.writeUInt16LE(16, 34);
b.write('data', 36); b.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) { b.writeInt16LE(Math.round(L[i] * g * 32767), 44 + i * 4); b.writeInt16LE(Math.round(R[i] * g * 32767), 46 + i * 4); }
writeFileSync(process.argv[2] || 'out/b3d/score.wav', b);
