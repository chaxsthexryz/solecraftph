// Shared helpers for the 20 s film. Everything here is a pure function of its inputs.
export const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
export const mix = (a, b, p) => a + (b - a) * p;

// Closed-form damped spring 0 → 1.
export function spring(t, k = 170, d = 26) {
  if (t <= 0) return 0;
  const w0 = Math.sqrt(k), z = d / (2 * w0);
  if (z < 1) {
    const wd = w0 * Math.sqrt(1 - z * z);
    return 1 - Math.exp(-z * w0 * t) * (Math.cos(wd * t) + (z * w0 / wd) * Math.sin(wd * t));
  }
  return 1 - Math.exp(-w0 * t) * (1 + w0 * t);
}
// keys: [[time, value], ...]; one spring per change, so any frame can be computed directly.
export function track(t, keys, k = 170, d = 26) {
  let v = keys[0][1];
  for (let i = 1; i < keys.length; i++) v += (keys[i][1] - keys[i - 1][1]) * spring(t - keys[i][0], k, d);
  return v;
}
export const load = (src) => new Promise((ok, bad) => { const i = new Image(); i.onload = () => ok(i); i.onerror = () => bad(new Error(src)); i.src = src; });

// Cut a product photo off its studio background: flood-fill from the border over pixels close to the
// background colour, then turn what was filled into a dark, translucent contact shadow.
export async function cutout(src, tol = 26, shadow = true) {
  const img = await load(src);
  const c = document.createElement('canvas'); c.width = img.naturalWidth; c.height = img.naturalHeight;
  const x = c.getContext('2d', { willReadFrequently: true }); x.drawImage(img, 0, 0);
  const W = c.width, H = c.height, d = x.getImageData(0, 0, W, H), p = d.data;
  const corners = [[1, 1], [W - 2, 1], [1, H - 2], [W - 2, H - 2]].map(([i, j]) => (j * W + i) * 4);
  const bg = [0, 1, 2].map((k) => Math.max(...corners.map((o) => p[o + k])));
  const bgL = (bg[0] + bg[1] + bg[2]) / 3;
  const dist = (o) => Math.max(Math.abs(p[o] - bg[0]), Math.abs(p[o + 1] - bg[1]), Math.abs(p[o + 2] - bg[2]));
  const seen = new Uint8Array(W * H), q = new Int32Array(W * H); let h = 0, tl = 0;
  const push = (i) => { if (!seen[i] && dist(i * 4) < tol) { seen[i] = 1; q[tl++] = i; } };
  for (let i = 0; i < W; i++) { push(i); push((H - 1) * W + i); }
  for (let j = 0; j < H; j++) { push(j * W); push(j * W + W - 1); }
  while (h < tl) { const i = q[h++], cx = i % W; if (cx > 0) push(i - 1); if (cx < W - 1) push(i + 1); if (i >= W) push(i - W); if (i < W * (H - 1)) push(i + W); }
  for (let i = 0; i < W * H; i++) {
    if (!seen[i]) continue;
    const o = i * 4, L = (p[o] + p[o + 1] + p[o + 2]) / 3;
    const a = shadow ? clamp((bgL - L - 3) / 70) * 0.75 : 0;   // only darker-than-ground pixels survive, as shadow
    p[o] = p[o + 1] = p[o + 2] = 12; p[o + 3] = Math.round(a * 255);
  }
  x.putImageData(d, 0, 0);
  return c;
}

// The splash logo is a blaze sole on white; key the white out so it sits on any ground.
export async function keyLogo(src, rgb = [0xE2, 0x41, 0x2A]) {
  const img = await load(src);
  const c = document.createElement('canvas'); c.width = img.naturalWidth; c.height = img.naturalHeight;
  const x = c.getContext('2d', { willReadFrequently: true }); x.drawImage(img, 0, 0);
  const d = x.getImageData(0, 0, c.width, c.height), p = d.data;
  for (let i = 0; i < p.length; i += 4) {
    const a = clamp((235 - Math.min(p[i], p[i + 1], p[i + 2])) / 175) * p[i + 3] / 255;
    [p[i], p[i + 1], p[i + 2]] = rgb; p[i + 3] = Math.round(a * 255);
  }
  x.putImageData(d, 0, 0); return c;
}
