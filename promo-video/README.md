# SoleCraftPH pitch promo (15 s, 16:9)

A 15-second promo for the SoleCraftPH business pitch, made entirely in code. The story follows the
business model summary: the problem (your size is sold out), the brand, and three solution features
(stock per size, GCash and card checkout, order tracking), then one account across web and app,
ending on the site URL.

- `out/solecraftph-promo.mp4`: final video, 1920×1080, 60 fps, H.264 + AAC, −14 LUFS
- `out/contact.png`: one frame every 0.5 s · `out/poster.png`: last frame
- `docs/shotlist.md`, `docs/style_guide.md`: the plan the film was built from

## How it works

`index.html` draws every frame on a canvas from `window.seek(t)` / `window.frame(t)`. That makes it a pure function
of time: closed-form springs, no timers, no `Math.random`. Open it in a browser for a live preview.

All app UI is real: `capture.mjs` screenshots each phone screen of the app's design source
(`../solecraftfinal/design/apple-draft/index.html`) into `assets/screens/` and records element positions
in `assets/layout.json`, which the cursor taps and overlays use. The laptop shows the website's own
screenshot (`server-patch/assets/screenshots/desktop.png`).

## Rebuild

```
npm install
node capture.mjs                     # only if the app screens changed
node render.mjs --sub 2              # → out/silent.mp4 (2 subframes blended per frame for motion blur)
node audio.mjs out/score.wav         # 120 BPM score + SFX, synthesized
ffmpeg -y -i out/silent.mp4 -i out/score.wav \
  -filter_complex "[1:a]atrim=0:15,afade=t=out:st=14.4:d=0.6,loudnorm=I=-14:TP=-1.0:LRA=9[a]" \
  -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 256k -shortest out/solecraftph-promo.mp4
node render.mjs --stills 2.5,7.9     # single frames for review
```

Fonts (Inter, Bebas Neue, Material Symbols Rounded; all SIL OFL) are vendored in `fonts/`, because headless
Chromium here cannot reach Google Fonts.
