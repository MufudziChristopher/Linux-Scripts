#!/bin/bash

# Script to record system audio using ffmpeg
# Requires: ffmpeg

FILENAME="${1:-recording_$(date +%Y%m%d-%H%M%S).mp3}"

# Check if ffmpeg is available
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg not found. Please install ffmpeg"
    echo "Ubuntu/Debian: sudo apt install ffmpeg"
    echo "Fedora: sudo dnf install ffmpeg"
    exit 1
fi

# Find the monitor source (may vary by system)
MONITOR_SOURCE=$(pactl list short sources | grep monitor | awk '{print $2}' | head -n1)

if [ -z "$MONITOR_SOURCE" ]; then
    echo "Error: Could not find monitor source"
    echo "Available sources:"
    pactl list short sources
    exit 1
fi

echo "Using monitor source: $MONITOR_SOURCE"
echo "Recording to: $FILENAME"
echo "Press q to stop recording"

# Record using ffmpeg
ffmpeg -f pulse -i "$MONITOR_SOURCE" -acodec libmp3lame -ab 128k "$FILENAME"
