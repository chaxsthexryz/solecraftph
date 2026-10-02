// Capture each phone screen from the app's design draft as a PNG.
import { chromium } from 'playwright';
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: 3 });
// Google Fonts is unreachable from headless Chromium here; serve the local copies in ./fonts
import { readFileSync, writeFileSync } from 'node:fs';
await page.route(/fonts\.(googleapis|gstatic)\.com/, (route) => {
  const u = route.request().url();
  if (u.includes('googleapis')) {
    const css = u.includes('Material') ? 'ms.css' : 'inter.css';
    return route.fulfill({ contentType: 'text/css', body: readFileSync('fonts/' + css, 'utf8').replace(/url\(([^)]+)\)/g, 'url(https://fonts.gstatic.com/local/$1)') });
  }
  return route.fulfill({ contentType: 'font/woff2', body: readFileSync('fonts/' + u.split('/').pop()) });
});
await page.goto('file://' + process.cwd() + '/../solecraftfinal/design/apple-draft/index.html');
await page.evaluate(async () => { await document.fonts.load('24px "Material Symbols Rounded"', "home"); await document.fonts.load('600 15px Inter'); await document.fonts.ready; });
await page.waitForTimeout(2500);
const figs = page.locator('figure');
const n = await figs.count();
const layout = {};
for (let i = 0; i < n; i++) {
  const f = figs.nth(i);
  const name = ((await f.locator('figcaption h2').textContent().catch(() => '')) || 'screen' + i)
    .trim().toLowerCase().replace(/[^a-z0-9]+/g, '-');
  await f.locator('.screen').first().screenshot({ path: `assets/screens/${String(i).padStart(2, '0')}-${name}.png` });
  const sc = f.locator('.screen').first();
  layout[name] = await sc.evaluate((root) => {
    const r0 = root.getBoundingClientRect(), out = [];
    for (const el of root.querySelectorAll('*')) {
      const txt = [...el.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent).join('').trim();
      if (!txt || txt.length > 40) continue;
      const r = el.getBoundingClientRect();
      out.push({ t: txt, x: +(r.x - r0.x).toFixed(1), y: +(r.y - r0.y).toFixed(1), w: +r.width.toFixed(1), h: +r.height.toFixed(1),
        bx: (() => { const b = el.closest('button,.chip,.size,.tile,li,a,[class*=btn],[class*=row]'); if (!b) return null; const q = b.getBoundingClientRect(); return [q.x - r0.x, q.y - r0.y, q.width, q.height].map((v) => +v.toFixed(1)); })() });
    }
    return { w: r0.width, h: r0.height, els: out };
  });
  console.log(i, name);
}
writeFileSync('assets/layout.json', JSON.stringify(layout, null, 1));
await browser.close();
