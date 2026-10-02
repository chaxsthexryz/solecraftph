#!/usr/bin/env bash
# Composite Blender frames + type overlay, mix the score to -14 LUFS and encode the final MP4.
# bash film3d/finish.sh            (run from promo-video/, after render.py, overlay.mjs and audio.mjs)
set -euo pipefail
ffmpeg -loglevel error -y -framerate 30 -i out/b3d/frames/%04d.png -framerate 30 -i out/b3d/overlay/%04d.png -i out/b3d/score.wav \
  -filter_complex "[0:v][1:v]overlay=format=auto,format=yuv420p[v];[2:a]atrim=0:20,loudnorm=I=-13.5:TP=-1.0:LRA=9[a]" \
  -map "[v]" -map "[a]" -c:v libx264 -crf 15 -preset slow -r 30 -c:a aac -b:a 256k -ar 48000 -shortest out/solecraftph-promo-3d.mp4
ffmpeg -loglevel error -y -i out/solecraftph-promo-3d.mp4 -vf "fps=2,scale=320:-1,tile=6x7" -frames:v 1 out/contact-3d.png
ffmpeg -loglevel error -y -sseof -0.05 -i out/solecraftph-promo-3d.mp4 -frames:v 1 -update 1 out/poster-3d.png
ffmpeg -i out/solecraftph-promo-3d.mp4 -af ebur128 -f null - 2>&1 | grep -E "^\s+I:" | tail -1
