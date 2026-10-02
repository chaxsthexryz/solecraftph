// node render.mjs [--fps 60] [--dur 15] [--from 0] [--sub 2] [--out out/silent.mp4] [--stills 0.5,2.4,...]
// Serves this folder over HTTP (so the canvas is not tainted), walks time through window.frame(t)
// and pipes JPEG frames into ffmpeg. --sub N renders N subframes per frame and blends them (motion blur).
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { extname, join } from 'node:path';

const argv = process.argv;
const arg = (k, d) => { const i = argv.indexOf('--' + k); return i > 0 ? argv[i + 1] : d; };
const FPS = +arg('fps', 60), DUR = +arg('dur', 15), FROM = +arg('from', 0), SUB = +arg('sub', 2);
const OUT = arg('out', 'out/silent.mp4'), STILLS = arg('stills', '');
mkdirSync('out', { recursive: true });

const TYPES = { '.html': 'text/html', '.css': 'text/css', '.png': 'image/png', '.woff2': 'font/woff2', '.js': 'text/javascript' };
const server = createServer((req, res) => {
  try { const p = join(process.cwd(), decodeURIComponent(req.url.split('?')[0]));
    res.writeHead(200, { 'content-type': TYPES[extname(p)] || 'application/octet-stream' }); res.end(readFileSync(p)); }
  catch { res.writeHead(404); res.end(); }
}).listen(0);
const port = server.address().port;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
await page.goto(`http://127.0.0.1:${port}/index.html`);
await page.evaluate(() => window.ready);
const grab = async (t) => Buffer.from((await page.evaluate((t) => window.frame(t, 0.95), t)).split(',')[1], 'base64');

if (STILLS) {
  for (const t of STILLS.split(',').map(Number)) writeFileSync(`out/still-${t.toFixed(2)}.jpg`, await grab(t));
} else {
  const vf = SUB > 1 ? `tmix=frames=${SUB},select='eq(mod(n\\,${SUB})\\,${SUB - 1})',setpts=N/${FPS}/TB` : 'null';
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-c:v', 'mjpeg', '-framerate', String(FPS * SUB), '-i', '-',
    '-vf', vf, '-r', String(FPS), '-c:v', 'libx264', '-crf', '16', '-preset', 'slow', '-pix_fmt', 'yuv420p', OUT],
    { stdio: ['pipe', 'inherit', 'inherit'] });
  const total = Math.round(DUR * FPS * SUB);
  for (let i = 0; i < total; i++) {
    // Subframes sit just before each frame's time, so the blended frame ends exactly at t.
    const png = await grab(Math.max(0, FROM + (Math.floor(i / SUB) + (i % SUB + 1 - SUB) / SUB) / FPS));
    if (!ff.stdin.write(png)) await new Promise((r) => ff.stdin.once('drain', r));
    if (i % (FPS * SUB) === 0) console.log(`rendered ${(i / (FPS * SUB)).toFixed(0)}s / ${DUR}s`);
  }
  ff.stdin.end();
  await new Promise((r) => ff.on('close', r));
}
await browser.close(); server.close();
