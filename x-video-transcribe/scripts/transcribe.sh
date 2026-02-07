#!/bin/bash
# transcribe.sh — Transcribe X/Twitter video from a tweet URL
# Usage: transcribe.sh <tweet-url> [--summary] [--output <file>]
#
# Requires: bird CLI (with cookies/env), ffmpeg, curl, GEMINI_API_KEY
set -euo pipefail

TWEET_URL=""
SUMMARY=false
OUTPUT=""
BIRD_ENV="${BIRD_ENV:-$HOME/agent-workspace/secrets/bird.env}"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-2.0-flash}"
TMPDIR="${TMPDIR:-/tmp}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary) SUMMARY=true; shift ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --model) GEMINI_MODEL="$2"; shift 2 ;;
    *) TWEET_URL="$1"; shift ;;
  esac
done

if [[ -z "$TWEET_URL" ]]; then
  echo "Usage: transcribe.sh <tweet-url> [--summary] [--output <file>]"
  echo ""
  echo "Options:"
  echo "  --summary   Include a brief summary after the transcript"
  echo "  --output    Save transcript to file"
  echo "  --model     Gemini model (default: gemini-2.0-flash)"
  exit 1
fi

# Check deps
if ! command -v bird &>/dev/null; then
  echo "❌ bird CLI not found. Install it or check PATH."
  exit 1
fi
if ! command -v ffmpeg &>/dev/null; then
  echo "❌ ffmpeg not found."
  exit 1
fi
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "❌ GEMINI_API_KEY not set."
  exit 1
fi

# Load bird env if available
if [[ -f "$BIRD_ENV" ]]; then
  export $(cat "$BIRD_ENV" | grep -v '^#' | xargs)
fi

WORK="$TMPDIR/x-transcribe-$$"
mkdir -p "$WORK"
trap "rm -rf $WORK" EXIT

echo "🐦 Fetching tweet..." >&2

# Step 1: Get video URL from tweet
TWEET_JSON=$(bird read "$TWEET_URL" --json 2>/dev/null)
VIDEO_URL=$(echo "$TWEET_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
media = data.get('media', [])
for m in media:
    if m.get('type') == 'video' and m.get('videoUrl'):
        print(m['videoUrl'])
        break
" 2>/dev/null)

if [[ -z "$VIDEO_URL" ]]; then
  echo "❌ No video found in tweet." >&2
  # Show tweet text anyway
  echo "$TWEET_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"@{data['author']['username']}: {data['text']}\")
" 2>/dev/null
  exit 1
fi

AUTHOR=$(echo "$TWEET_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"@{d['author']['username']} ({d['author']['name']})\")" 2>/dev/null)
TWEET_TEXT=$(echo "$TWEET_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['text'])" 2>/dev/null)
DURATION=$(echo "$TWEET_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('media', []):
    if m.get('durationMs'):
        secs = m['durationMs'] // 1000
        print(f'{secs//60}m {secs%60}s')
        break
" 2>/dev/null)

echo "📥 Downloading video ($DURATION)..." >&2

# Step 2: Download video
curl -sL -o "$WORK/video.mp4" "$VIDEO_URL"

echo "🎵 Extracting audio..." >&2

# Step 3: Extract audio
ffmpeg -i "$WORK/video.mp4" -vn -acodec libmp3lame -q:a 5 "$WORK/audio.mp3" -y 2>/dev/null

AUDIO_SIZE=$(stat -c%s "$WORK/audio.mp3" 2>/dev/null || stat -f%z "$WORK/audio.mp3" 2>/dev/null)

echo "☁️  Uploading to Gemini..." >&2

# Step 4: Upload audio to Gemini
UPLOAD_RESPONSE=$(curl -s -X POST \
  "https://generativelanguage.googleapis.com/upload/v1beta/files?key=${GEMINI_API_KEY}" \
  -H "X-Goog-Upload-Command: start, upload, finalize" \
  -H "X-Goog-Upload-Header-Content-Length: ${AUDIO_SIZE}" \
  -H "X-Goog-Upload-Header-Content-Type: audio/mpeg" \
  -H "Content-Type: audio/mpeg" \
  --data-binary @"$WORK/audio.mp3")

FILE_URI=$(echo "$UPLOAD_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['file']['uri'])" 2>/dev/null)

if [[ -z "$FILE_URI" ]]; then
  echo "❌ Failed to upload audio to Gemini." >&2
  echo "$UPLOAD_RESPONSE" >&2
  exit 1
fi

echo "🤖 Transcribing..." >&2

# Step 5: Transcribe with Gemini
PROMPT="Transcribe this audio completely and accurately. Include all spoken words."
if [[ "$SUMMARY" == "true" ]]; then
  PROMPT="$PROMPT Then provide a brief summary at the end under a '## Summary' heading."
fi

TRANSCRIPT=$(curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"contents\": [{
      \"parts\": [
        {\"fileData\": {\"mimeType\": \"audio/mpeg\", \"fileUri\": \"${FILE_URI}\"}},
        {\"text\": \"${PROMPT}\"}
      ]
    }]
  }" | python3 -c "
import sys, json
r = json.load(sys.stdin)
try:
    print(r['candidates'][0]['content']['parts'][0]['text'])
except:
    print(json.dumps(r, indent=2))
" 2>/dev/null)

# Build output
RESULT="# X Video Transcript

**Author:** ${AUTHOR}
**Tweet:** ${TWEET_TEXT}
**Duration:** ${DURATION}
**URL:** ${TWEET_URL}

---

${TRANSCRIPT}"

if [[ -n "$OUTPUT" ]]; then
  echo "$RESULT" > "$OUTPUT"
  echo "✅ Saved to $OUTPUT" >&2
else
  echo "$RESULT"
fi
