#!/bin/bash

# Interactive Timelapse Creator
echo "=== FFmpeg Timelapse Generator ==="

# Get input file
read -p "Enter input video file: " INPUT
if [ ! -f "$INPUT" ]; then
  echo "Error: File not found!"
  exit 1
fi

# Get speed factor
read -p "Enter speed multiplier (default 20): " SPEED
SPEED=${SPEED:-20}
SPEED_PTS=$(echo "scale=4; 1/$SPEED" | bc)

# Get output filename
DEFAULT_OUT="${INPUT%.*}_${SPEED}x.mp4"
read -p "Enter output file (default $DEFAULT_OUT): " OUTPUT
OUTPUT=${OUTPUT:-$DEFAULT_OUT}

# Audio options
echo -n "Keep audio? [y/N] "
read KEEP_AUDIO
KEEP_AUDIO=${KEEP_AUDIO:-n}

# Build FFmpeg command
CMD=(ffmpeg -i "$INPUT" -vf "setpts=$SPEED_PTS*PTS")

if [[ "${KEEP_AUDIO,,}" == "y" ]]; then
  # Calculate required atempo chain (max 10x per filter)
  ATEMPO_CHAIN=""
  REMAINING=$SPEED
  while (( $(echo "$REMAINING > 2.0" | bc -l) )); do
    ATEMPO_CHAIN+="atempo=2.0,"
    REMAINING=$(echo "$REMAINING / 2.0" | bc -l)
  done
  ATEMPO_CHAIN+="atempo=$REMAINING"
  
  CMD+=(-af "$ATEMPO_CHAIN" -c:a aac -b:a 128k)
else
  CMD+=(-an)
fi

# Add encoding settings
CMD+=(
  -c:v libx264 -crf 18 -preset fast
  -movflags +faststart
  -y "$OUTPUT"
)

# Execute
echo -e "\nRunning:"
echo "${CMD[@]}"
"${CMD[@]}"

if [ $? -eq 0 ]; then
  echo -e "\nSuccess! Created timelapse: $OUTPUT"
  echo "Original duration: $(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")s"
  echo "Timelapse duration: $(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT")s"
else
  echo -e "\nError creating timelapse!"
  exit 1
fi
