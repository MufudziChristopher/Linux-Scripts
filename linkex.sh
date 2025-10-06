#!/bin/bash

# YouTube Playlist Link Extractor - Bash Script

# Check if yt-dlp is installed
if ! command -v yt-dlp &> /dev/null; then
    echo "Error: yt-dlp is not installed. Please install it first."
    echo "You can install it using:"
    echo "  pip install yt-dlp"
    echo "Or visit: https://github.com/yt-dlp/yt-dlp#installation"
    exit 1
fi

# Ask for playlist URL
read -p "Enter the YouTube playlist URL: " playlist_url

# Validate URL
if [[ ! "$playlist_url" =~ ^https?://(www\.)?youtube\.com ]]; then
    echo "Error: Invalid YouTube playlist URL"
    exit 1
fi

# Create output filename
output_file="youtube_playlist_links_$(date +%Y%m%d_%H%M%S).txt"

# Extract video URLs
echo "Extracting video links from playlist..."
yt-dlp --flat-playlist --get-url "$playlist_url" > "$output_file"

# Check if extraction was successful
if [ $? -eq 0 ] && [ -s "$output_file" ]; then
    count=$(wc -l < "$output_file")
    echo "Successfully extracted $count video links to $output_file"
else
    echo "Error: Failed to extract video links"
    rm -f "$output_file" 2>/dev/null
    exit 1
fi
