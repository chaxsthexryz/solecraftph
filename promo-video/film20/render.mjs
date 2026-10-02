// node film20/render.mjs [--fps 60] [--dur 20] [--from 0] [--sub 2] [--out out/film20-silent.mp4] [--stills 1.2,3.4]
// Serves promo-video/ over HTTP, sets each frame with window.seek(t) and screenshots the page
// (the film is DOM + CSS 3D, so the browser compositor draws it). --sub N blends N subframes per frame.
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { extname, join } from 'node:path';

const argv = process.argv, arg = (k, d) => { const i = argv.indexOf('--' + k); return i > 0 ? argv[i + 1] : d; };
const FPS = +arg('fps', 60), DUR = +arg('dur', 20), FROM = +arg('from', 0), SUB = +arg('sub', 2);
const OUT = arg('out', 'out/film20-silent.mp4'), STILLS = arg('stills', '');
mkdirSync('out', { recursive: true });

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.woff2': 'font/woff2' };
const server = createServer((q, r) => {
  try { const p = join(process.cwd(), decodeURIComponent(q.url.split('?')[0])); r.writeHead(200, { 'content-type': TYPES[extname(p)] || 'application/octet-stream' }); r.end(readFileSync(p)); }
  catch { r.writeHead(404); r.end(); }
}).listen(0);

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
page.on('pageerror', (e) => console.error('pageerror:', e.message));
await page.goto(`http://127.0.0.1:${server.address().port}/film20/index.html`);
await page.evaluate(() => window.ready);
const grab = async (t) => { await page.evaluate((t) => window.seek(t), t); return page.screenshot({ type: 'jpeg', quality: 95 }); };

if (STILLS) {
  for (const t of STILLS.split(',').map(Number)) writeFileSync(`out/f20-${t.toFixed(3)}.jpg`, await grab(t));
} else {
  const vf = SUB > 1 ? `tmix=frames=${SUB},select='eq(mod(n\\,${SUB})\\,${SUB - 1})',setpts=N/${FPS}/TB` : 'null';
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-c:v', 'mjpeg', '-framerate', String(FPS * SUB), '-i', '-',
    '-vf', vf, '-r', String(FPS), '-c:v', 'libx264', '-crf', '15', '-preset', 'slow', '-pix_fmt', 'yuv420p', OUT], { stdio: ['pipe', 'inherit', 'inherit'] });
  const total = Math.round(DUR * FPS * SUB);
  for (let i = 0; i < total; i++) {
    // subframes sit just before each frame time, so the blended frame ends exactly on t
    const t = FROM + (Math.floor(i / SUB) + (i % SUB + 1 - SUB) / SUB) / FPS;
    const jpg = await grab(Math.max(0, t));
    if (!ff.stdin.write(jpg)) await new Promise((r) => ff.stdin.once('drain', r));
    if (i % (FPS * SUB) === 0) console.log(`rendered ${(i / (FPS * SUB)).toFixed(0)}s / ${DUR}s`);
  }
  ff.stdin.end(); await new Promise((r) => ff.on('close', r));
}
await browser.close(); server.close();
