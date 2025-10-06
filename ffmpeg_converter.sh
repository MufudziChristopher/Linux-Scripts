#!/bin/bash

# Usage: ffmpeg_converter.sh <input_file> <source_format> <target_format> [quality/bitrate]
# Example: ffmpeg_converter.sh input.mp3 mp3 ogg 6

# ====== CONFIGURATION ======
# Supported formats (extend this list as needed)
declare -A SUPPORTED_FORMATS=(
    # === Audio ===
    ["mp3"]="libmp3lame -q:a"
    ["ogg"]="libvorbis -q:a"
    ["wav"]="pcm_s16le"
    ["flac"]="flac -compression_level"
    ["m4a"]="aac -b:a"
    ["aac"]="aac -b:a"
    ["opus"]="libopus -b:a"
    ["wma"]="wmav2 -b:a"
    ["aiff"]="pcm_s16le"
    ["ac3"]="ac3 -b:a"
    ["amr"]="libopencore_amrnb -b:a"
    ["alac"]="alac"
    ["dsd"]="dsd -codec dsd"

    # === Video ===
    ["mp4"]="libx264 -crf"
    ["mkv"]="libx264 -crf"
    ["webm"]="libvpx-vp9 -crf"
    ["avi"]="mpeg4 -q:v"
    ["mov"]="libx264 -crf"
    ["flv"]="flv -q:v"
    ["wmv"]="wmv2 -b:v"
    ["3gp"]="h263 -b:v"
    ["gif"]="gif"
    ["vob"]="mpeg2video -b:v"
)

HW_ACCEL="auto"  # auto/cuda/vaapi/none

# === Functions ===
fail() {
    echo "❌ Error: $1" >&2
    exit 1
}

validate_input() {
    local file="$1"
    [ -z "$file" ] && fail "No input file specified"
    
    # Handle relative/absolute paths and spaces
    if ! full_path=$(realpath -- "$file" 2>/dev/null); then
        fail "File not found: '$file'"
    fi

    [ ! -f "$full_path" ] && fail "Not a regular file: '$full_path'"
    echo "$full_path"
}

generate_output() {
    local input="$1" target_fmt="$2"
    echo "${input%.*}_converted_$(date +%s).${target_fmt}"
}

# === Main ===
if [ "$1" = "--batch" ]; then
    # Batch mode
    shift
    pattern="$1"
    target_fmt="$2"
    quality="${3:-}"

    # Expand pattern safely
    shopt -s nullglob
    files=($pattern)
    shopt -u nullglob

    [ ${#files[@]} -eq 0 ] && fail "No files match: '$pattern'"

    for file in "${files[@]}"; do
        input=$(validate_input "$file") || continue
        output=$(generate_output "$input" "$target_fmt")
        
        echo "🔁 Converting: $input → $output"
        ffmpeg -i "$input" -c:a ${CODEC_MAP[$target_fmt]%% *} ${CODEC_MAP[$target_fmt]#* } $quality "$output" ||
            echo "⚠️  Failed: $input"
    done
else
    # Single file mode
    input=$(validate_input "$1") || exit 1
    source_fmt="${2:-${input##*.}}"
    target_fmt="$3"
    quality="${4:-}"
    output=$(generate_output "$input" "$target_fmt")

    # Build command
    cmd=(ffmpeg -i "$input")
    
    # Hardware acceleration
    case "$HW_ACCEL" in
        cuda) cmd+=(-hwaccel cuda -hwaccel_output_format cuda) ;;
        vaapi) cmd+=(-vaapi_device /dev/dri/renderD128 -hwaccel vaapi) ;;
        auto) cmd+=(-hwaccel auto) ;;
    esac

    # Codec and quality
    IFS=' ' read -r codec flags <<< "${CODEC_MAP[$target_fmt]}"
    [ -n "$codec" ] || fail "Unsupported format: $target_fmt"
    cmd+=(-c:v "$codec" -c:a "$codec")
    [ -n "$flags" ] && [ -n "$quality" ] && cmd+=($flags "$quality")

    # Metadata and output
    cmd+=(-map_metadata 0 -map 0 "$output")

    echo "🔁 Converting: $input → $output"
    "${cmd[@]}" && echo "✅ Success" || fail "Conversion failed"
fi
