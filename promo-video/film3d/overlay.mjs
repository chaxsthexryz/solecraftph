// node film3d/overlay.mjs [--stills f1,f2] — renders the transparent type layer to out/b3d/overlay/%04d.png (30 fps).
import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFileSync, mkdirSync } from 'node:fs';
import { extname, join } from 'node:path';
const T = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.json': 'application/json', '.woff2': 'font/woff2' };
const s = createServer((q, r) => { try { const p = join(process.cwd(), decodeURIComponent(q.url.split('?')[0])); r.writeHead(200, { 'content-type': T[extname(p)] || 'application/octet-stream' }); r.end(readFileSync(p)); } catch { r.writeHead(404); r.end(); } }).listen(0);
const b = await chromium.launch(); const page = await b.newPage({ viewport: { width: 1920, height: 1080 } });
page.on('pageerror', (e) => console.error('pageerror', e.message));
await page.goto(`http://127.0.0.1:${s.address().port}/film3d/overlay.html`); await page.waitForFunction(() => window.done);
const i = process.argv.indexOf('--stills'); const frames = i > 0 ? process.argv[i + 1].split(',').map(Number) : [...Array(600).keys()];
mkdirSync('out/b3d/overlay', { recursive: true });
for (const f of frames) { await page.evaluate((t) => window.seek(t), f / 30); await page.screenshot({ path: `out/b3d/overlay/${String(f).padStart(4, '0')}.png`, omitBackground: true }); }
console.log('overlay frames', frames.length); await b.close(); s.close();
