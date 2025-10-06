#!/bin/bash

# Smart Video+Audio Merger with Looping
echo "=== Video/Audio Looping Combiner ==="

# Input validation
read -p "Enter video file (MP4): " VIDEO
if [[ ! -f "$VIDEO" ]]; then
    echo "❌ Error: Video file not found!"
    exit 1
fi

read -p "Enter audio file (MP3): " AUDIO
if [[ ! -f "$AUDIO" ]]; then
    echo "❌ Error: Audio file not found!"
    exit 1
fi

# Get durations
VIDEO_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO")
AUDIO_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO")

# Output filename
DEFAULT_OUT="${VIDEO%.*}_with_audio.mp4"
read -p "Enter output file [$DEFAULT_OUT]: " OUTPUT
OUTPUT=${OUTPUT:-$DEFAULT_OUT}

# Looping strategy
echo ""
echo "Duration mismatch handling:"
echo "Video: ${VIDEO_DUR}s | Audio: ${AUDIO_DUR}s"
echo "1) Loop video to match audio (default)"
echo "2) Loop audio to match video"
echo "3) Trim longer to match shorter"
read -p "Choose strategy [1]: " LOOP_CHOICE
LOOP_CHOICE=${LOOP_CHOICE:-1}

# Audio mixing options
echo ""
echo "Audio Mixing Options:"
echo "1) Replace original audio"
echo "2) Mix with original audio (soundtrack quieter)"
echo "3) Mix with original audio (balanced)"
read -p "Choose mixing mode [1]: " MIX_MODE
MIX_MODE=${MIX_MODE:-1}

# Build FFmpeg command
case $LOOP_CHOICE in
    1)
        # Loop video to match audio duration
        LOOP_TIMES=$(awk -v v=$VIDEO_DUR -v a=$AUDIO_DUR 'BEGIN{print int(a/v)+1}')
        VIDEO_FILTER=" -stream_loop $LOOP_TIMES -i \"$VIDEO\" "
        AUDIO_FILTER=" -i \"$AUDIO\" "
        DURATION_OPT=" -t $AUDIO_DUR "
        ;;
    2)
        # Loop audio to match video duration
        LOOP_TIMES=$(awk -v v=$VIDEO_DUR -v a=$AUDIO_DUR 'BEGIN{print int(v/a)+1}')
        VIDEO_FILTER=" -i \"$VIDEO\" "
        AUDIO_FILTER=" -stream_loop $LOOP_TIMES -i \"$AUDIO\" "
        DURATION_OPT=" -t $VIDEO_DUR "
        ;;
    3)
        # No looping - trim to shortest
        VIDEO_FILTER=" -i \"$VIDEO\" "
        AUDIO_FILTER=" -i \"$AUDIO\" "
        DURATION_OPT=" -shortest "
        ;;
    *)
        echo "Invalid choice, using video looping"
        LOOP_TIMES=$(awk -v v=$VIDEO_DUR -v a=$AUDIO_DUR 'BEGIN{print int(a/v)+1}')
        VIDEO_FILTER=" -stream_loop $LOOP_TIMES -i \"$VIDEO\" "
        AUDIO_FILTER=" -i \"$AUDIO\" "
        DURATION_OPT=" -t $AUDIO_DUR "
        ;;
esac

# Audio mixing
case $MIX_MODE in
    1)
        # Replace audio
        AUDIO_MAP="-map 1:a"
        ;;
    2)
        # Mix with quieter soundtrack
        FILTER_COMPLEX=" -filter_complex \"[0:a][1:a]amerge=inputs=2,pan=stereo|c0<c0+c1|c1<c0+c1[a]\" "
        AUDIO_MAP="-map \"[a]\""
        ;;
    3)
        # Balanced mix
        FILTER_COMPLEX=" -filter_complex \"[1:a]volume=0.5[a1];[0:a][a1]amerge=inputs=2,pan=stereo|c0<c0+c1|c1<c0+c1[a]\" "
        AUDIO_MAP="-map \"[a]\""
        ;;
    *)
        FILTER_COMPLEX=""
        AUDIO_MAP="-map 1:a"
        ;;
esac

# Build final command
CMD="ffmpeg $VIDEO_FILTER $AUDIO_FILTER $FILTER_COMPLEX -map 0:v $AUDIO_MAP -c:v copy -c:a aac -b:a 192k $DURATION_OPT -y \"$OUTPUT\""

# Execute
echo -e "\nRunning command:"
echo "$CMD"
eval "$CMD"

if [[ $? -eq 0 ]]; then
    echo -e "\n✅ Successfully created: $OUTPUT"
    echo "Final duration: $(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT")s"
else
    echo -e "\n❌ Error processing files!"
    exit 1
fi
