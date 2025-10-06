#!/bin/bash

# Reliable Timelapse Creator
if [ -z "$1" ]; then
  echo "Usage: $0 input.mp4 [output_duration_seconds] [soundtrack.mp3]"
  echo "Example: $0 video.mp4 90"
  echo "Example with audio: $0 video.mp4 90 music.mp3"
  exit 1
fi

# Verify input file exists
INPUT="$1"
if [ ! -f "$INPUT" ]; then
  echo "Error: Input file $INPUT not found!"
  exit 1
fi

OUTPUT="${INPUT%.*}_timelapse.mp4"
TARGET_DUR=${2:-90}  # Default to 90 seconds
MUSIC="$3"

# Get original duration (in seconds)
ORIG_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")
if [ -z "$ORIG_DUR" ]; then
  echo "Error: Could not get duration of input file!"
  exit 1
fi

# Calculate required speedup factor
SPEED=$(echo "$ORIG_DUR / $TARGET_DUR" | bc -l)

echo "Creating ${TARGET_DUR}s timelapse (speedup: ${SPEED}x)..."

# Build FFmpeg command
CMD=(ffmpeg -i "$INPUT")

if [ -n "$MUSIC" ]; then
  # Verify music file exists
  if [ ! -f "$MUSIC" ]; then
    echo "Error: Music file $MUSIC not found!"
    exit 1
  fi
  CMD+=(-i "$MUSIC")
fi

# Video filter
CMD+=(-vf "setpts=PTS/$SPEED")

# Audio handling
if [ -n "$MUSIC" ]; then
  # Use only the music (ignore original audio)
  CMD+=(-map 0:v -map 1:a -shortest)
else
  # Check if input has audio
  HAS_AUDIO=$(ffprobe -i "$INPUT" -show_streams -select_streams a 2>&1 | grep "Audio:")
  if [ -n "$HAS_AUDIO" ]; then
    CMD+=(-filter:a "atempo=$SPEED")
  else
    CMD+=(-an)
  fi
fi

# Encoding settings
CMD+=(
  -c:v libx264 -preset fast -crf 23
  -c:a aac -b:a 128k
  -y "$OUTPUT"
)

# Execute command
echo "Running:"
echo "${CMD[@]}"
"${CMD[@]}"

if [ $? -eq 0 ]; then
  echo "Successfully created timelapse: $OUTPUT"
  echo "Output duration: $(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT") seconds"
else
  echo "Error creating timelapse!"
  exit 1
fi
