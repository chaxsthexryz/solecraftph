// node film3d/prep.mjs — writes film3d/assets/ (textures) and film3d/seq/ (animated phone screens) for Blender.
import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { extname, join } from 'node:path';
const T = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.woff2': 'font/woff2' };
const s = createServer((q, r) => { try { const p = join(process.cwd(), decodeURIComponent(q.url.split('?')[0])); r.writeHead(200, { 'content-type': T[extname(p)] || 'application/octet-stream' }); r.end(readFileSync(p)); } catch { r.writeHead(404); r.end(); } }).listen(0);
const b = await chromium.launch(); const page = await b.newPage();
page.on('pageerror', (e) => console.error('pageerror', e.message));
await page.goto(`http://127.0.0.1:${s.address().port}/film3d/prep.html`);
await page.waitForFunction(() => window.done); await page.evaluate(() => window.prep.init());
const save = (path, url) => writeFileSync(path, Buffer.from(url.split(',')[1], 'base64'));
for (const d of ['film3d/assets/shoes', 'film3d/seq/panelA', 'film3d/seq/phone']) mkdirSync(d, { recursive: true });
for (const [k, u] of Object.entries(await page.evaluate(() => window.prep.shoes()))) save(`film3d/assets/shoes/${k}.png`, u);
save('film3d/assets/logo.png', await page.evaluate(() => window.prep.logo()));
(await page.evaluate(() => window.prep.notes())).forEach((u, i) => save(`film3d/assets/note${i}.png`, u));
save('film3d/assets/keyboard.png', await page.evaluate(() => window.prep.keyboard()));
for (const f of ['../assets/desktop.png', '../assets/screens/02-bag.png', '../assets/screens/07-order-detail.png']) writeFileSync(`film3d/assets/${f.split('/').pop()}`, readFileSync(join('film3d', f)));
// animated screens, one file per scene frame (30 fps)
for (let f = 140; f <= 300; f++) save(`film3d/seq/panelA/${String(f).padStart(4, '0')}.jpg`, await page.evaluate((f) => window.prep.panelA(f), f));
for (let f = 60; f <= 380; f++) save(`film3d/seq/phone/${String(f).padStart(4, '0')}.jpg`, await page.evaluate((f) => window.prep.phone(f), f));
console.log('prep done'); await b.close(); s.close();
