#!/usr/bin/env bash
# Composes the promo video from clips + helpers + soundtrack. Repo root.
set -euo pipefail
O="tool/marketing/out"
V="marketing/video"
mkdir -p "$O/scenes"

# This ffmpeg build has no drawtext (no libfreetype); captions are
# pre-rendered transparent PNGs (cap_*.png, made with Pillow + the same
# Space Grotesk font) overlaid with an alpha fade instead.
cap() {  # cap <in-clip> <out-scene> <dur> <caption-png>
  ffmpeg -y -loglevel error \
    -loop 1 -t "$3" -i "$O/gradient_1080x1920.png" \
    -i "$O/clips/$1.mp4" -loop 1 -t "$3" -i "$O/phone_frame_overlay.png" \
    -loop 1 -t "$3" -i "$O/$4" \
    -filter_complex "
      [1:v]scale=900:-2,crop=900:1560:0:'(ih-1560)/2',setpts=PTS-STARTPTS[clip];
      [0:v][clip]overlay=90:180[base];
      [base][2:v]overlay=0:0[framed];
      [3:v]format=rgba,fade=in:st=0:d=0.5:alpha=1[cap];
      [framed][cap]overlay=0:60,fps=30,format=yuv420p" \
    -t "$3" -an "$O/scenes/$2.mp4"
  echo "scene $2"
}

# Intro: gradient with slow zoom; icon and wordmark fade in (alpha fades on
# pre-rendered PNGs — drawtext unavailable in this ffmpeg build).
ffmpeg -y -loglevel error -loop 1 -t 3 -i "$O/gradient_1080x1920.png" \
  -loop 1 -t 3 -i "$O/intro_icon.png" \
  -loop 1 -t 3 -i "$O/wordmark.png" \
  -filter_complex "
    [0:v]zoompan=z='1+0.02*in/90':d=90:s=1080x1920[bg];
    [1:v]format=rgba,fade=in:st=0:d=1.0:alpha=1[icon];
    [2:v]format=rgba,fade=in:st=1.2:d=0.6:alpha=1[wm];
    [bg][icon]overlay=(W-w)/2:660[a];
    [a][wm]overlay=0:1120,fps=30,format=yuv420p" \
  -t 3 -an "$O/scenes/00_intro.mp4"

cap explore 01_explore 6 cap_explore.png
cap detail  02_detail  6 cap_detail.png
cap saved   03_saved   6 cap_saved.png
cap dark    04_dark    4 cap_dark.png

ffmpeg -y -loglevel error -loop 1 -t 3 -i "$O/outro.png" \
  -vf "zoompan=z='1.04-0.013*in/90':d=90:s=1080x1920,fade=out:st=2.5:d=0.5,fps=30,format=yuv420p" \
  -t 3 -an "$O/scenes/05_outro.mp4"

# Crossfade chain (0.5 s): 3+6+6+6+4+3 - 5*0.5 = 25.5 s total.
ffmpeg -y -loglevel error \
  -i "$O/scenes/00_intro.mp4" -i "$O/scenes/01_explore.mp4" \
  -i "$O/scenes/02_detail.mp4" -i "$O/scenes/03_saved.mp4" \
  -i "$O/scenes/04_dark.mp4" -i "$O/scenes/05_outro.mp4" \
  -i "$V/soundtrack.wav" \
  -filter_complex "
    [0:v][1:v]xfade=transition=fade:duration=0.5:offset=2.5[a];
    [a][2:v]xfade=transition=fade:duration=0.5:offset=8[b];
    [b][3:v]xfade=transition=fade:duration=0.5:offset=13.5[c];
    [c][4:v]xfade=transition=fade:duration=0.5:offset=19[d];
    [d][5:v]xfade=transition=fade:duration=0.5:offset=22.5[vid];
    [6:a]atrim=0:25.5,afade=t=out:st=23.5:d=2[aud]" \
  -map "[vid]" -map "[aud]" -c:v libx264 -preset slow -crf 20 \
  -c:a aac -b:a 160k -movflags +faststart "$V/wallify_promo.mp4"

# README previews.
ffmpeg -y -loglevel error -i "$V/wallify_promo.mp4" \
  -vf scale=720:-2 -c:v libx264 -crf 28 -an "$V/wallify_promo_preview.mp4"
# fps/scale/palette tuned to keep the GIF under GitHub's 10 MB render limit.
ffmpeg -y -loglevel error -i "$V/wallify_promo.mp4" \
  -vf "fps=8,scale=400:-2,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
  "$V/wallify_promo_preview.gif"
ls -lh "$V"
