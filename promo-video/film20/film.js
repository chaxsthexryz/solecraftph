// SoleCraftPH 20 s pitch promo. Pure function of time: window.seek(t) sets every element for frame t.
// 96 BPM: one beat = 0.625 s, one bar = 2.5 s, eight bars. Every scene starts on a bar.
import { clamp, mix, spring, track, load, cutout, keyLogo } from './lib.js';

const W = 1920, H = 1080, DUR = 20, B = 0.625;
const C = { ink: '#111111', blaze: '#E2412A', paper: '#FAF9F6', stone: '#EDEAE3', gray: '#8A8578', label: '#6E6A60', white: '#FFFFFF', mist: 'rgb(243,241,236)' };
const URL_TEXT = 'snow-jellyfish-553645.hostingersite.com';
const $ = (id) => document.getElementById(id);
const world = $('world'), top = $('topworld'), fx = $('fx'), ground = $('ground');
const html = (s) => { const t = document.createElement('template'); t.innerHTML = s.trim(); return t.content.firstChild; };

// ---------- scene graph ----------
function obj(inner, w, h, parent = world, cls = '') {
  const el = html(`<div class="o ${cls}" style="width:${w}px;height:${h}px">${inner}</div>`);
  el._w = w; el._h = h; parent.appendChild(el); return el;
}
function place(el, { x = 960, y = 540, z = 0, rx = 0, ry = 0, rz = 0, s = 1, o = 1, f = '' } = {}) {
  if (o <= 0.002 || s <= 0.002) { el.style.visibility = 'hidden'; return; }
  el.style.visibility = 'visible';
  el.style.transform = `translate3d(${x - el._w / 2}px,${y - el._h / 2}px,${z}px) rotateX(${rx}deg) rotateY(${ry}deg) rotateZ(${rz}deg) scale(${s})`;
  el.style.opacity = o < 0.999 ? o : '';
  el.style.filter = f;
}
const hide = (el) => { el.style.visibility = 'hidden'; };

// Display type: a line slides up from behind its mask on enter and up out on exit.
const LINES = [];
function line(parts, x, y, px, tIn, tOut, parent = world, z = 0, cut = 99) {
  const el = html(`<div class="kl" style="font:400 ${px}px/${px}px 'Bebas Neue';height:${px * 0.86}px;padding-right:${px * 0.1}px"><div>${parts.map(([s, c]) => `<span style="color:${c}">${s}</span>`).join('')}</div></div>`);
  el.style.transform = `translate3d(${x}px,${y - px * 0.8}px,${z}px)`;
  parent.appendChild(el); LINES.push({ el, inner: el.firstChild, px, tIn, tOut, cut, k: 'line' });
}
function sub(text, x, y, tIn, tOut, parent = world, color = C.label, px = 38, weight = 500) {
  const el = html(`<div class="sub" style="font:${weight} ${px}px/1.3 Inter;color:${color}"><div>${text}</div></div>`);
  el.style.transform = `translate3d(${x}px,${y - px}px,0)`;
  parent.appendChild(el); LINES.push({ el, inner: el.firstChild, px, tIn, tOut, k: 'sub' });
}
function linesAt(t) {
  for (const L of LINES) {
    const pIn = spring(t - L.tIn, 210, 26), pOut = spring(t - L.tOut, 260, 30);
    if (pIn <= 0.001 || pOut >= 0.999 || t >= (L.cut ?? 99)) { L.el.style.visibility = 'hidden'; continue; }
    L.el.style.visibility = 'visible';
    L.inner.style.transform = L.k === 'line'
      ? `translateY(${(1 - pIn) * L.px * 1.0 - pOut * L.px * 1.05}px)`
      : `translateY(${(1 - pIn) * L.px * 1.4 - pOut * L.px * 1.6}px)`;
  }
}

// ---------- assets ----------
const SHOES = { kayano: 'kayano31.webp', pegasus: 'pegasus41.png', metcon: 'metcon9.jpg', ghost: 'ghost16.jpg', clifton: 'clifton9.jpg', af1: 'af1.jpg' };
const SCREENS = { 'shoe-details': '01-shoe-details', bag: '02-bag', checkout: '03-checkout', 'order-placed': '05-order-placed', 'order-detail': '07-order-detail', notifications: '08-notifications' };
const IMG = {}, CUT = {}, ASPECT = {};
let logoURL = '';

// ---------- the phone (screen is a 3x canvas in the draft's 340×760 CSS-px space) ----------
let phone, sc;
const SLOT = { x: 28.3125, y: 107.796875, w: 283.359375, h: 212.40625, box: [16, 100, 308, 228] };  // Kayano photo on Shoe Details
const TAP = { size: 6.25, add: 6.875, gcash: 8.125, place: 9.375 };
const LAND = 5.55;                                 // hero shoe lands in the product slot
let SPIN_SWAP = 7.5;                              // computed: when the spinning phone shows its back

function drawScreen(name, dx = 0) { const im = IMG[name]; sc.drawImage(im, dx, 0, 340, im.height * 340 / im.width); }
function rr(x, y, w, h, r) { sc.beginPath(); sc.roundRect(x, y, w, h, r); }
function tile(x, y, w, h, label, mode, p = 1) {
  sc.save(); sc.translate(x + w / 2, y + h / 2);
  const s = mode === 'filled' ? 0.84 + 0.16 * p : mode === 'sold' ? 0.9 + 0.1 * p : 1; sc.scale(s, s);
  rr(-w / 2, -h / 2, w, h, 12);
  sc.fillStyle = mode === 'filled' ? C.ink : mode === 'sold' ? C.stone : C.white; sc.fill();
  if (mode !== 'filled') { sc.strokeStyle = C.stone; sc.lineWidth = 1; sc.stroke(); }
  sc.fillStyle = mode === 'filled' ? C.white : mode === 'sold' ? '#B4AFA4' : C.ink;
  sc.font = `${mode === 'filled' ? 600 : 500} 15px Inter`; sc.textAlign = 'center'; sc.textBaseline = 'middle'; sc.fillText(label, 0, 1);
  if (mode === 'sold') { sc.strokeStyle = '#B4AFA4'; sc.lineWidth = 1.5; sc.beginPath(); sc.moveTo(-w / 2 + 8, h / 2 - 8); sc.lineTo(w / 2 - 8, -h / 2 + 8); sc.stroke(); }
  sc.restore();
}
function press(x, y, w, h, r, t, at) {
  const a = clamp(1 - Math.abs(t - at - 0.06) / 0.14) * 0.22; if (a <= 0) return;
  rr(x, y, w, h, r); sc.fillStyle = `rgba(0,0,0,${a})`; sc.fill();
}
function check(x, y, col) {
  sc.save(); sc.strokeStyle = col; sc.lineWidth = 2.4; sc.lineCap = 'round'; sc.lineJoin = 'round';
  sc.beginPath(); sc.moveTo(x + 4, y + 12.5); sc.lineTo(x + 9.5, y + 18); sc.lineTo(x + 20, y + 7); sc.stroke(); sc.restore();
}
function overlays(name, t) {
  if (name === 'shoe-details') {
    if (t < LAND) { rr(...SLOT.box, 24); sc.fillStyle = C.mist; sc.fill(); }        // the slot waits for the hero shoe
    const xs = { 9: 120.7, 10: 173, 12: 277.7 };
    if (t >= 5.625) tile(xs[12], 472, 46.3, 48, '12', 'sold', spring(t - 5.625, 380, 18));
    if (t >= TAP.size) { tile(xs[9], 472, 46.3, 48, '9', 'plain'); tile(xs[10], 472, 46.3, 48, '10', 'filled', spring(t - TAP.size, 420, 22)); }
    press(175, 688, 149, 50, 25, t, TAP.add);
    const ty = track(t, [[0, 0], [TAP.add + 0.1, 1], [7.25, 0]], 300, 30);
    if (ty > 0.01) {
      sc.save(); sc.translate(170, 640 + (1 - ty) * 60); sc.globalAlpha = clamp(ty * 1.4);
      rr(-90, -20, 180, 40, 20); sc.fillStyle = C.ink; sc.fill();
      sc.fillStyle = C.white; sc.font = '600 14px Inter'; sc.textAlign = 'center'; sc.textBaseline = 'middle';
      sc.fillText('Added to Bag', 8, 1); check(-82, -12, C.blaze); sc.restore();
    }
  }
  if (name === 'checkout') {
    if (t >= TAP.gcash) {
      sc.fillStyle = C.white; sc.fillRect(282, 360, 32, 32);
      const p = spring(t - TAP.gcash, 380, 24);
      sc.save(); sc.translate(298, 426.5); sc.scale(p, p); check(-12, -12, C.blaze); sc.restore();
    }
    press(181.8, 688, 142.3, 50, 25, t, TAP.place);
  }
}
let NAV;
function screenAt(t) {
  let i = 0; for (let j = 0; j < NAV.length; j++) if (t >= NAV[j][0]) i = j;
  const [t0, name, mode] = NAV[i], p = mode === 'push' ? spring(t - t0, 240, 30) : 1;
  if (p < 0.999) {
    const prev = NAV[i - 1][1];
    sc.save(); sc.translate(-p * 110, 0); drawScreen(prev); overlays(prev, t); sc.restore();
    sc.fillStyle = `rgba(0,0,0,${0.18 * p})`; sc.fillRect(0, 0, 340, 760);
    sc.save(); sc.translate(340 * (1 - p), 0); sc.shadowColor = 'rgba(0,0,0,.25)'; sc.shadowBlur = 30;
    sc.fillStyle = C.white; sc.fillRect(0, 0, 340, 760); sc.shadowBlur = 0; drawScreen(name); overlays(name, t); sc.restore();
  } else { drawScreen(name); overlays(name, t); }
}
const CUR = [[5.7, 230, 640], [5.8, 196, 496], [6.5, 250, 713], [7.8, 170, 520], [7.85, 120, 426], [8.85, 253, 713]];
function cursor(t) {
  const vis = t < 7.45 ? Math.min(spring(t - 5.75, 200, 26), 1 - spring(t - 7.05, 260, 30))
                       : Math.min(spring(t - 7.85, 200, 26), 1 - spring(t - 9.6, 260, 30));
  if (vis <= 0.01) return;
  const x = track(t, CUR.map(([k, x]) => [k, x]), 140, 24), y = track(t, CUR.map(([k, , y]) => [k, y]), 140, 24);
  let down = 0, rip = -1;
  for (const k of Object.values(TAP)) { down = Math.max(down, clamp(1 - Math.abs(t - k - 0.05) / 0.12)); if (t >= k && t < k + 0.5) rip = t - k; }
  sc.save(); sc.globalAlpha = vis;
  if (rip >= 0) { sc.beginPath(); sc.arc(x, y, 18 + 70 * spring(rip, 90, 18), 0, 7); sc.strokeStyle = `rgba(226,65,42,${0.8 * (1 - rip / 0.5)})`; sc.lineWidth = 3; sc.stroke(); }
  sc.beginPath(); sc.arc(x, y, 20 * (1 - 0.22 * down), 0, 7); sc.fillStyle = 'rgba(17,17,17,.28)'; sc.fill();
  sc.lineWidth = 3; sc.strokeStyle = C.white; sc.stroke(); sc.restore();
}

// Phone placement. Rotations are cumulative degrees, so the 360° spin is one key.
const P = {
  x: [[0, 1300], [5.6, 1340], [9.6, 980], [12.5, 1640]],
  y: [[0, 1750], [4.9, 540], [5.6, 346], [6.5, 400], [7.2, 540], [7.75, 471], [8.75, 447], [9.6, 540], [12.5, 650]],
  s: [[0, 1.12], [5.6, 1.5], [6.5, 1.38], [7.2, 1.25], [7.75, 1.5], [8.75, 1.3], [9.6, 1.15], [12.5, 0.74]],
  rx: [[0, 0], [5.6, 5], [7.2, 0], [7.75, 4], [9.6, 0]],
  ry: [[0, 0], [5.6, -14], [7.2, -374], [9.6, -348], [12.5, -380]],
  rz: [[0, 0], [12.5, 2]],
  z: [[0, 0], [12.5, 200]],
};
const PK = { z: [150, 24], x: [150, 24], y: [150, 22], s: [150, 26], rx: [120, 22], ry: [70, 15], rz: [120, 22] };
const phoneAt = (t) => Object.fromEntries(Object.keys(P).map((k) => [k, track(t, P[k], ...PK[k])]));

// ---------- build ----------
let E = {};
async function build() {
  for (const [k, f] of Object.entries(SCREENS)) IMG[k] = await load(`../assets/screens/${f}.png`);
  for (const [k, f] of Object.entries(SHOES)) { const c = await cutout(`../assets/shoes/${f}`); CUT[k] = c.toDataURL('image/png'); ASPECT[k] = c.height / c.width; }
  logoURL = (await keyLogo('../assets/splash-logo.png')).toDataURL('image/png');
  await Promise.all(['400 100px "Bebas Neue"', '400 20px Inter', '500 20px Inter', '600 20px Inter'].map((f) => document.fonts.load(f)));
  await document.fonts.ready;

  const shoe = (k, w, parent = world) => obj(`<img src="${CUT[k]}">`, w, Math.round(w * ASPECT[k]), parent, 'shoe');
  const shadow = (w, h, parent = world) => { const el = obj('', w, h, parent); el.classList.add('shadow'); return el; };

  // 1 · hook (0–2.5)
  E.glow = obj(`<div style="width:100%;height:100%;background:radial-gradient(closest-side,rgba(226,65,42,.42),rgba(226,65,42,0))"></div>`, 1500, 1100);
  E.hero = shoe('kayano', 900);
  E.tiles = ['7', '8', '9', '10', '11', '12'].map((l) => obj(`<div style="width:100%;height:100%;box-sizing:border-box;border:3px solid #3A3936;border-radius:28px;display:grid;place-items:center;font:600 46px Inter;color:${C.paper};position:relative">${l}<svg viewBox="0 0 120 120" style="position:absolute;inset:0"><line x1="18" y1="102" x2="102" y2="18" stroke="${C.blaze}" stroke-width="10" stroke-linecap="round" pathLength="1" stroke-dasharray="1" stroke-dashoffset="1"/></svg></div>`, 120, 120));
  line([['FOUND', C.paper]], 130, 420, 220, 0.06, 1.18, world, 0, 2.5);
  line([['THE PAIR.', C.paper]], 130, 620, 220, 0.14, 1.22, world, 0, 2.5);
  line([['YOUR SIZE?', C.paper]], 130, 420, 220, 1.25, 2.6, world, 0, 2.5);
  line([['SOLD OUT.', C.blaze]], 130, 620, 220, 1.33, 2.6, world, 0, 2.5);

  // 2 · brand (2.5–5): the catalogue turns on a carousel; the Kayano ends up in front.
  E.ring = ['pegasus', 'metcon', 'ghost', 'clifton', 'kayano', 'af1'].map((k) => ({ k, el: shoe(k, 440), sh: shadow(380, 60) }));
  E.logo = obj(`<img src="${logoURL}" style="width:100%;height:100%">`, 330, 330);
  line([['SOLE', C.ink], ['CRAFT', C.blaze], ['PH', C.ink]], 130, 630, 180, 2.75, 4.85);
  sub('Footwear, done right.', 136, 712, 2.95, 4.85, world, C.label, 44);

  // 3–6 · the phone
  phone = obj(`<div class="pf front"><canvas width="1020" height="2280"></canvas></div>
    <div class="pf back"><div class="lens"></div><img src="${logoURL}" style="width:250px;height:250px"></div>
    <div class="edge l"></div><div class="edge r"></div><div class="edge t"></div><div class="edge b"></div>`, 360, 780, world, 'phone p3');
  sc = phone.querySelector('canvas').getContext('2d');
  line([['STOCK SHOWN', C.ink]], 130, 470, 180, 5.25, 7.2);
  line([['PER ', C.ink], ['SIZE.', C.blaze]], 130, 640, 180, 5.33, 7.25);
  sub('See what’s left before you fall for a pair.', 136, 745, 5.6, 7.2);
  line([['PAY WITH', C.ink]], 130, 470, 170, 7.6, 9.75);
  line([['GCASH ', C.blaze], ['OR CARD.', C.ink]], 130, 635, 170, 7.68, 9.8);
  sub('Secure checkout through PayMongo.', 136, 740, 7.95, 9.75);
  line([['TRACK EVERY', C.ink]], 110, 470, 165, 9.95, 12.3);
  line([['ORDER.', C.blaze]], 110, 630, 165, 10.03, 12.35);
  sub('A live timeline, any time.', 116, 730, 10.3, 12.3);
  E.cards = [199.1, 145.7, 252.6].map((sy) => {
    const el = obj(`<div></div>`, 525, 109, world, 'card'), k = 525 / 300;
    Object.assign(el.firstChild.style, { backgroundImage: `url(../assets/screens/${SCREENS.notifications}.png)`, backgroundSize: `${340 * k}px auto`, backgroundPosition: `${-26 * k}px ${-(sy - 4) * k}px` });
    return el;
  });

  // 6 · one account (12.5–15)
  E.laptop = obj(`<div class="lid"><img src="../assets/desktop.png"></div><div class="deck"></div>`, 940, 600, world, 'p3');
  line([['ONE ACCOUNT.', C.ink]], 110, 360, 135, 12.6, 14.8);
  line([['WEB AND ', C.ink], ['APP.', C.blaze]], 110, 505, 135, 12.68, 14.85);
  sub('Your cart and orders follow you.', 116, 590, 12.95, 14.8, world, C.label, 34);

  // 7 · lineup (15–17.5), a second set one screen to the right: the camera trucks over to it.
  E.lineup = ['kayano', 'pegasus', 'metcon', 'ghost', 'clifton', 'af1'].map((k) => ({
    k, el: shoe(k, 290), refl: obj(`<img src="${CUT[k]}" style="width:100%;height:100%;transform:scaleY(-1);-webkit-mask-image:linear-gradient(to top,rgba(0,0,0,.22),rgba(0,0,0,0) 55%)">`, 290, Math.round(290 * ASPECT[k])), sh: shadow(260, 40),
  }));
  line([['100% ', C.ink], ['AUTHENTIC.', C.ink]], 1920 + 120, 330, 160, 15.12, 99);
  line([['BELOW ', C.ink], ['MALL PRICES.', C.blaze]], 1920 + 120, 490, 160, 15.2, 99);

  // 8 · CTA (17.5–20), above the ink that rises over everything
  E.glow2 = obj(`<div style="width:100%;height:100%;background:radial-gradient(closest-side,rgba(226,65,42,.38),rgba(226,65,42,0))"></div>`, 1400, 1000, top);
  E.hero2 = shoe('kayano', 780, top);
  E.shadow2 = shadow(700, 70, top);
  E.logo2 = obj(`<img src="${logoURL}" style="width:100%;height:100%">`, 300, 300, top);
  line([['SOLE', C.paper], ['CRAFT', C.blaze], ['PH', C.paper]], 140, 690, 200, 17.85, 99, top);
  sub('Footwear, done right.', 146, 778, 18.1, 99, top, '#CFCBC2', 44);
  E.url = obj(`<div class="url" style="position:relative;overflow:hidden;height:64px;line-height:64px;padding:0 4px"><span>${URL_TEXT}</span><i style="position:absolute;left:4px;bottom:4px;height:4px;width:0;background:${C.blaze}"></i></div>`, 760, 64, top);

  // wipes
  E.slab = html(`<div class="o" style="width:2700px;height:1400px;left:-390px;top:-160px;background:${C.blaze}"></div>`); fx.appendChild(E.slab);
  E.rise = [C.blaze, C.ink].map((c) => { const el = html(`<div class="o" style="width:1920px;height:1080px;background:${c}"></div>`); fx.appendChild(el); return el; });

  // When does the spinning phone turn its back to us? Swap to Checkout there.
  for (let t = 7.2; t < 8.5; t += 0.001) if (track(t, P.ry, ...PK.ry) <= -14 - 180) { SPIN_SWAP = t; break; }
  NAV = [[0, 'shoe-details', 'cut'], [SPIN_SWAP, 'checkout', 'cut'], [9.6, 'order-placed', 'push'], [10.625, 'order-detail', 'push'], [12.5, 'bag', 'push']];
}

// ---------- per-frame ----------
const ringAngle = (t) => track(t, [[0, -40], [2.5, 0], [3.125, -60], [3.75, -120], [4.375, -180], [5.0, -240]], 160, 22);

function seek(t) {
  t = clamp(t, 0, DUR);
  ground.style.background = t < 2.5 ? C.ink : t < 17.5 ? C.paper : C.ink;

  // camera
  const cam = {
    x: track(t, [[0, 0], [15.0, 1920]], 110, 24),
    y: 0,
    z: t < 2.5 ? 150 * spring(t, 3, 3.5) : track(t, [[0, 0], [2.5, 0], [5.0, 40], [12.5, 0], [15.2, 90]], 40, 14),
    rx: track(t, [[0, 0], [2.5, 3], [5.0, 0], [12.5, 2], [15.0, 0]], 60, 16),
    ry: track(t, [[0, -2.5], [2.5, 3], [5.0, 0], [12.5, -4], [15.0, 2], [16.5, -1]], 30, 11),
    rz: track(t, [[0, 0], [7.2, -1.2], [9.6, 0]], 60, 16),
  };
  world.style.transformOrigin = `${960 + cam.x}px ${540 + cam.y}px`;
  world.style.transform = `translate3d(${-cam.x}px,${-cam.y}px,${cam.z}px) rotateX(${cam.rx}deg) rotateY(${cam.ry}deg) rotateZ(${cam.rz}deg)`;

  linesAt(t);

  // 1 · hook
  if (t < 2.5) {
    const inP = spring(t, 110, 17), dead = spring(t - 1.5625, 90, 20);
    place(E.hero, { x: mix(2350, 1330, inP), y: mix(330, 500, inP) + 40 * dead, z: mix(500, 0, inP) - 260 * dead,
      ry: mix(-60, -10, inP) + 6 * spring(t - 0.5, 4, 4), rz: mix(-14, -5, inP), f: `grayscale(${dead}) brightness(${1 - 0.5 * dead})` });
    place(E.glow, { x: 1300, y: 520, z: -380, o: clamp(inP * 1.2) * (1 - 0.9 * dead), s: 0.9 + 0.1 * inP });
    E.tiles.forEach((el, i) => {
      const p = spring(t - 0.55 - i * 0.07, 260, 22);
      place(el, { x: 960 + i * 140 + 60, y: 880 + (1 - p) * 90, z: 40, rx: 18, o: clamp(p * 1.5) });
      const slashAt = { 2: 1.5625, 3: 1.875, 1: 2.1875 }[i];
      const ln = el.querySelector('line');
      ln.setAttribute('stroke-dashoffset', slashAt ? 1 - spring(t - slashAt, 380, 30) : 1);
      el.firstChild.style.borderColor = i === 2 && t >= 0.9375 && t < 1.5625 ? C.blaze : '#3A3936';
    });
  } else { hide(E.hero); hide(E.glow); E.tiles.forEach(hide); }

  // 2 · brand carousel
  if (t >= 2.3 && t < 5.7) {
    const rise = spring(t - 2.45, 150, 22), a0 = ringAngle(t);
    E.ring.forEach(({ k, el, sh }, i) => {
      const a = (a0 + i * 60) * Math.PI / 180, R = 360;
      const x = 1460 + R * Math.sin(a), z = R * Math.cos(a) - R, y = 560 + (1 - rise) * 900;
      if (k === 'kayano' && t >= 4.95) { hide(el); hide(sh); return; }            // handed over to the flying hero
      const exit = spring(t - 4.9, 160, 24);
      place(el, { x, y: y + exit * 900, z, ry: -Math.sin(a) * 22, f: `brightness(${1 + z / 2400})` });
      place(sh, { x, y: y + 440 * ASPECT[k] * 0.5 + 4 + exit * 900, z: z - 1, o: 0.9 });
    });
    const lp = spring(t - 2.6, 120, 14), lo = spring(t - 4.85, 260, 30);
    place(E.logo, { x: 270, y: 300 - lo * 700, rz: (1 - lp) * -40 - 12, s: 0.3 + 0.7 * lp, o: clamp(lp * 3) });
  } else { E.ring.forEach(({ el, sh }) => { hide(el); hide(sh); }); hide(E.logo); }

  // 3–6 · phone
  const ph = phoneAt(t);
  if (t >= 4.85 && t < 15.6) {
    place(phone, { x: ph.x, y: ph.y, z: ph.z, rx: ph.rx, ry: ph.ry, rz: ph.rz, s: ph.s });
    sc.setTransform(3, 0, 0, 3, 0, 0); sc.clearRect(0, 0, 340, 760); sc.fillStyle = C.white; sc.fillRect(0, 0, 340, 760);
    screenAt(t); cursor(t);
  } else hide(phone);

  // match cut: the carousel's Kayano flies into the product slot on the phone
  if (t >= 4.95 && t < LAND) {
    const a = (ringAngle(t) + 4 * 60) * Math.PI / 180, R = 360;
    const fx0 = 1460 + R * Math.sin(a), fz0 = R * Math.cos(a) - R;
    const p = spring(t - 4.95, 140, 24);
    const tx = ph.x + ph.s * (SLOT.x + SLOT.w / 2 - 170), ty = ph.y + ph.s * (SLOT.y + SLOT.h / 2 - 380);
    place(E.hero, { x: mix(fx0, tx, p), y: mix(560, ty, p), z: mix(fz0, 6 * ph.s, p) + 260 * Math.sin(Math.PI * p),
      s: mix(440 / 900, SLOT.w * ph.s / 900, p), ry: mix(-Math.sin(a) * 22, 0, p) });
  }

  // 5 · notifications fly out of the phone toward the camera
  E.cards.forEach((el, i) => {
    const at = 10.625 + i * B, p = spring(t - at, 170, 20), out = spring(t - 12.35 - i * 0.06, 220, 28);
    if (p <= 0.001 || out >= 0.999) return hide(el);
    place(el, { x: mix(ph.x, 1480, p) + out * 900, y: mix(ph.y - 120, 330 + i * 190, p), z: mix(-40, 90, p), ry: mix(0, -16, p), s: mix(0.35, 1, p) });
  });

  // 6 · laptop
  if (t >= 12.3 && t < 15.8) {
    const p = spring(t - 12.5, 120, 22);
    place(E.laptop, { x: mix(2700, 1130, p), y: 420, z: -220, rx: -16, ry: mix(-50, -26, p) + 4 * spring(t - 13.75, 20, 9) });
  } else hide(E.laptop);

  // 7 · lineup: pairs drop onto the shelf on eighth notes
  if (t >= 14.9 && t < 17.8) {
    E.lineup.forEach(({ k, el, refl, sh }, i) => {
      const at = 15.3125 + i * B / 2, p = spring(t - at, 210, 19), h = 290 * ASPECT[k];
      const x = 1920 + 222 + i * 295 + (1 - p) * 1500, base = 840;
      if (t < at) { hide(el); hide(refl); hide(sh); return; }
      const rz = -9 * (1 - p) * (1 - p);
      place(el, { x, y: base - h / 2, z: 0, rz });
      place(refl, { x, y: base + h / 2, z: 0, rz: -rz, o: clamp(p * 1.3) });
      place(sh, { x, y: base - 4, z: -1, s: 0.6 + 0.4 * p, o: clamp(p * 1.4) });
    });
  } else E.lineup.forEach(({ el, refl, sh }) => { hide(el); hide(refl); hide(sh); });

  // 8 · CTA
  if (t >= 17.4) {
    const p = spring(t - 17.55, 100, 16), l = spring(t - 17.7, 120, 14);
    place(E.hero2, { x: mix(2500, 1450, p), y: 470, z: mix(300, 0, p), ry: mix(55, -8, p) - 3 * spring(t - 18.5, 3, 3.5), rz: mix(10, -4, p) });
    place(E.shadow2, { x: mix(2500, 1450, p), y: 470 + 780 * ASPECT.kayano * 0.5 - 20, z: -20, s: p, o: 0.8 });
    place(E.glow2, { x: 1430, y: 470, z: -400, o: clamp(p * 1.3) });
    place(E.logo2, { x: 250, y: 330, rz: (1 - l) * -50 - 12, s: 0.25 + 0.75 * l, o: clamp(l * 3) });
    const u = spring(t - 18.35, 200, 26);
    place(E.url, { x: 140 + 380, y: 870 + (1 - u) * 40, o: clamp(u * 1.5) });
    E.url.querySelector('i').style.width = `${(E.url.querySelector('span').offsetWidth) * spring(t - 18.5, 160, 26)}px`;
  } else { hide(E.hero2); hide(E.shadow2); hide(E.glow2); hide(E.logo2); hide(E.url); }

  // wipes: a skewed blaze slab covers the cut at 2.5 and leaves; ink rises at 17.5 and stays
  const sIn = spring(t - 2.12, 320, 34), sOut = spring(t - 2.5, 260, 32);
  const sx = (1 - sIn) * 2900 - sOut * 2900;
  E.slab.style.transform = `translateX(${sx}px) skewX(-14deg)`;
  E.slab.style.visibility = t > 2.0 && t < 3.2 ? 'visible' : 'hidden';
  const r1 = spring(t - 17.2, 200, 28), r2 = spring(t - 17.3, 200, 28);
  E.rise[0].style.transform = `translateY(${(1 - r1) * 1100}px)`; E.rise[0].style.visibility = t > 17.1 ? 'visible' : 'hidden';
  E.rise[1].style.transform = `translateY(${(1 - r2) * 1100}px)`; E.rise[1].style.visibility = t > 17.2 ? 'visible' : 'hidden';
  return true;
}

window.ready = build().then(() => { window.seek = seek; seek(0); return true; });
window.seek = () => false;
// Live preview in a normal browser; scaled to the window. Off during headless render.
const fit = () => { $('frame').style.transform = `scale(${Math.min(innerWidth / W, innerHeight / H)})`; };
if (!navigator.webdriver) { fit(); addEventListener('resize', fit);
  window.ready.then(() => { const t0 = performance.now(); (function loop() { seek(((performance.now() - t0) / 1000) % DUR); requestAnimationFrame(loop); })(); }); }
