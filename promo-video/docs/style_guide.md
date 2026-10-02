# Style guide

- **Palette (brand tokens from the app):** ink `#111111`, blaze `#E2412A` (the one accent), paper `#FAF9F6`, stone `#EDEAE3`, warm grey `#8A8578`.
- **Type:** Bebas Neue for display (the website's headline face), Inter for UI and supporting lines. Nothing else.
- **Layout:** text on a left column, product on the right. No centered title on a gradient, no corner labels, no frame borders.
- **Motion:** closed-form springs only (`spring`, `track`). Text enters by sliding up behind a mask, never by fading. UI pushes like native navigation. Taps show a touch dot with a ripple.
- **Pacing:** something changes on every beat; a new idea every 2–3 s.
- **Sound:** 120 BPM score and SFX synthesized in `audio.mjs`, every cut on the beat grid, loudness −14 LUFS.
