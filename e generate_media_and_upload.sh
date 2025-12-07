#!/usr/bin/env bash
set -euo pipefail
# Usage:
# generate_media_and_upload.sh "<voiceScript>" "<safe_title>" "<caption>" "<image_urls_json>"
# image_urls_json is optional JSON array string: '["url1","url2",...]'

VOICE_SCRIPT="$1"
SAFE_TITLE="$2"
CAPTION="$3"
IMAGE_URLS_JSON="${4:-[]}"

TMPDIR="/tmp/n8n_viral_$(date +%s)"
mkdir -p "$TMPDIR"
cd "$TMPDIR"

# 1) Create TTS (gTTS)
python3 - <<PY
from gtts import gTTS
import sys
text = sys.argv[1]
t = gTTS(text, lang='en')
t.save('voice.mp3')
PY "$VOICE_SCRIPT"

# 2) Download images (expect up to 4); if none provided, use placeholder images
python3 - <<PY
import sys, json, urllib.request
urls = json.loads(sys.argv[1])
if not urls:
    urls = [f'https://picsum.photos/720/1280?random={i}' for i in range(1,5)]
# ensure exactly 4 images
urls = (urls + urls[:4])[:4]
for i, u in enumerate(urls, start=1):
    fname = f'img{i}.jpg'
    try:
        urllib.request.urlretrieve(u, fname)
    except Exception as e:
        # fallback to picsum
        urllib.request.urlretrieve(f'https://picsum.photos/720/1280?random={i}', fname)
PY "$IMAGE_URLS_JSON"

# 3) Build a video slideshow (each image 2.5s -- total length will match audio)
# Create ffmpeg input file list
for i in 1 2 3 4; do
  echo "file 'img${i}.jpg'" >> imgs.txt
  echo "duration 2.5" >> imgs.txt
done
# repeat last frame to avoid ffmpeg shortlastframe issue
echo "file 'img4.jpg'" >> imgs.txt

# Make the slideshow (vertical 720x1280)
ffmpeg -y -f concat -safe 0 -i imgs.txt -vf "scale=720:1280,format=yuv420p" -c:v libx264 -r 30 -pix_fmt yuv420p slideshow.mp4

# 4) Combine audio and video, trim/pad to match audio length
# get audio duration
AUDIODUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 voice.mp3)
# Merge
ffmpeg -y -i slideshow.mp4 -i voice.mp3 -c:v copy -c:a aac -shortest output.mp4

# 5) Print path of final file (n8n Execute Command will capture it)
echo "{\"final_path\":\"$TMPDIR/output.mp4\",\"title\":\"$SAFE_TITLE\",\"caption\":\"$CAPTION\"}"
