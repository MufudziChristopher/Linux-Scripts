#!/bin/bash

# Configuration
SEGMENT_DURATION=300      # 5 minute segments
WEB_CAM_SIZE="320x240"    # Webcam PiP size
FPS=30                    # Frame rate
QUALITY=18                # CRF value (18-23 is good)
BASE_DIR="$HOME/Videos/ScreenRecordings"
SESSION_ID=$(date +%Y%m%d_%H%M%S)
SESSION_DIR="$BASE_DIR/$SESSION_ID"

# Create session directory
mkdir -p "$SESSION_DIR"

# Get screen resolution
SCREEN_RES=$(xdpyinfo | grep dimensions | awk '{print $2}')

# Find next available part number
LAST_PART=$(find "$SESSION_DIR" -name "part*.mp4" | sort | tail -n 1 | grep -oE '[0-9]+' || echo "0")
NEXT_PART=$((LAST_PART + 1))

# FFmpeg recording command with PiP
ffmpeg \
  -f x11grab -video_size "$SCREEN_RES" -framerate $FPS -i :0.0 \
  -f v4l2 -video_size "$WEB_CAM_SIZE" -framerate $FPS -i /dev/video0 \
  -filter_complex \
    "[1:v]scale=${WEB_CAM_SIZE%x*}:-1[webcam]; \
     [0:v][webcam]overlay=main_w-overlay_w-10:10[v]" \
  -map "[v]" \
  -c:v libx264 -crf $QUALITY -preset fast \
  -f segment -segment_time $SEGMENT_DURATION \
  -segment_start_number "$NEXT_PART" \
  -reset_timestamps 1 \
  -movflags +faststart \
  -flags +global_header \
  "$SESSION_DIR/part%03d.mp4"

echo "Recording screen+cam to: $SESSION_DIR"
