# SoleCraftPH pitch promos (16:9)

Two cuts: a 20-second cinematic version (`film20/`, below) and the original 15-second version.

## 20 s cinematic cut

- `out/solecraftph-promo-20s.mp4`: 1920×1080, 60 fps, H.264 + AAC, −14 LUFS · `out/contact-20s.png` · `out/poster-20s.png`
- 96 BPM, eight 2.5 s bars, one scene per bar: hook (sold out) → brand carousel → match cut into the app → stock per size
  → phone spin to GCash/card checkout → order tracking → web and app → lineup → logo and URL.
- `film20/film.js` builds the film from DOM + CSS 3D (real perspective camera, a phone with a back and edges, a laptop) and sets
  every element from `window.seek(t)`; the phone screen is a canvas drawing the captured app screens. `film20/lib.js` has the
  springs and the shoe cutout (flood-fill from the photo border, background turned into a soft contact shadow).
- Shoe photos are the app draft's own (`assets/shoes/`); claims come from the business model summary and the site's own marquee.

```
node film20/audio.mjs out/film20-score.wav
node film20/render.mjs --sub 2                 # → out/film20-silent.mp4 (screenshots each subframe)
ffmpeg -y -i out/film20-silent.mp4 -i out/film20-score.wav \
  -filter_complex "[1:a]atrim=0:20,loudnorm=I=-13.5:TP=-1.0:LRA=9[a]" \
  -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 256k -shortest out/solecraftph-promo-20s.mp4
node film20/render.mjs --stills 2.5,9.0       # single frames for review
```

Open `film20/index.html` through any static server (e.g. `npx serve .`) for a live preview.

## 15 s original cut

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
