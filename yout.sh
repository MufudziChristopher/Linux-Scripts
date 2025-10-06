#!/bin/bash

# Check if yt-dlp or youtube-dl is installed
if command -v yt-dlp &> /dev/null; then
    DOWNLOADER="yt-dlp"
    echo "Using yt-dlp (recommended)"
elif command -v youtube-dl &> /dev/null; then
    DOWNLOADER="youtube-dl"
    echo "Using youtube-dl"
else
    echo "Error: Neither yt-dlp nor youtube-dl is installed."
    echo "Install yt-dlp with:"
    echo "sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp && sudo chmod +x /usr/local/bin/yt-dlp"
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Install it first."
    echo "Debian/Ubuntu: sudo apt install ffmpeg"
    echo "Fedora: sudo dnf install ffmpeg"
    echo "Arch: sudo pacman -S ffmpeg"
    exit 1
fi

# Check if URL and format are provided
if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <URL> <output_format> [options]"
    echo "Formats: mp3, mp4, flac, etc."
    echo "Options: --cookies, --retry, --throttle"
    exit 1
fi

URL="$1"
FORMAT="$2"
OPTION="${3:-}"

echo "Downloading: $URL"
echo "Format: $FORMAT"

# Function to handle Spotify links
download_spotify() {
    if [[ "$URL" == *"open.spotify.com/playlist"* ]] || [[ "$URL" == *"open.spotify.com/album"* ]]; then
        echo "Detected Spotify playlist/album. Downloading all tracks..."
        
        if command -v yt-dlp &> /dev/null; then
            echo "Using yt-dlp for Spotify (may require cookies)"
            case "$FORMAT" in
                mp3)
                    yt-dlp -x --audio-format mp3 --audio-quality 0 "$URL"
                    ;;
                mp4)
                    yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" "$URL"
                    ;;
                *)
                    yt-dlp -f "$FORMAT" "$URL"
                    ;;
            esac
        elif command -v spotify-dl &> /dev/null; then
            echo "Using spotify-dl..."
            spotify-dl -o "$FORMAT" "$URL"
        else
            echo "Error: For Spotify support, install either:"
            echo "1. yt-dlp, OR"
            echo "2. spotify-dl: pip install spotify-dl"
            exit 1
        fi
    else
        echo "Detected Spotify single track..."
        if command -v yt-dlp &> /dev/null; then
            case "$FORMAT" in
                mp3)
                    yt-dlp -x --audio-format mp3 --audio-quality 0 "$URL"
                    ;;
                mp4)
                    yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" "$URL"
                    ;;
                *)
                    yt-dlp -f "$FORMAT" "$URL"
                    ;;
            esac
        elif command -v spotify-dl &> /dev/null; then
            spotify-dl -o "$FORMAT" "$URL"
        else
            echo "Error: Spotify support requires yt-dlp or spotify-dl"
            exit 1
        fi
    fi
}

# Function to handle YouTube downloads with various workarounds
download_youtube() {
    local is_playlist="$1"
    local playlist_flag=""
    
    if [ "$is_playlist" = true ]; then
        echo "Detected YouTube playlist. Downloading all videos..."
        playlist_flag="--yes-playlist"
    else
        playlist_flag="--no-playlist"
    fi
    
    # Base command
    local base_cmd="$DOWNLOADER $playlist_flag"
    
    # Apply options based on user choice or auto-detect issues
    case "$OPTION" in
        --cookies)
            echo "Using browser cookies method..."
            cmd="$base_cmd --cookies-from-browser chrome"
            ;;
        --retry)
            echo "Using retry method with different formats..."
            cmd="$base_cmd --retries 10 --fragment-retries 10 --skip-unavailable-fragments"
            ;;
        --throttle)
            echo "Using throttled download to avoid detection..."
            cmd="$base_cmd --sleep-interval 5 --max-sleep-interval 10 --retries 10"
            ;;
        *)
            # Auto-detect: try multiple methods
            echo "Trying auto-recovery methods for 403 errors..."
            cmd="$base_cmd --retries 5 --fragment-retries 5 --throttled-rate 100K"
            ;;
    esac
    
    # Add format-specific options
    case "$FORMAT" in
        mp3)
            cmd="$cmd -x --audio-format mp3 --audio-quality 0"
            ;;
        mp4)
            cmd="$cmd -f \"bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best\""
            ;;
        *)
            cmd="$cmd -f \"$FORMAT\""
            ;;
    esac
    
    # Add common workarounds for 403 errors
    cmd="$cmd --no-part --hls-prefer-native --downloader ffmpeg"
    
    # Execute the command
    echo "Executing: $cmd \"$URL\""
    eval "$cmd \"$URL\""
    
    # If failed, try alternative methods
    if [ $? -ne 0 ]; then
        echo "First attempt failed. Trying alternative methods..."
        
        # Method 1: Try with different user agent
        echo "Method 1: Trying with different user agent..."
        eval "$base_cmd --user-agent \"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36\" -x --audio-format mp3 --audio-quality 0 \"$URL\""
        
        if [ $? -ne 0 ]; then
            # Method 2: Try different format selection
            echo "Method 2: Trying different format selection..."
            eval "$base_cmd -f \"bestaudio/best\" -x --audio-format mp3 --audio-quality 0 \"$URL\""
        fi
        
        if [ $? -ne 0 ]; then
            # Method 3: Try with embedded options
            echo "Method 3: Trying embedded extractor..."
            eval "$base_cmd --extractor-args \"youtube:player_client=android_embedded\" -x --audio-format mp3 --audio-quality 0 \"$URL\""
        fi
    fi
}

# Function to handle SoundCloud playlists
download_soundcloud_playlist() {
    echo "Detected SoundCloud playlist. Downloading all tracks..."
    
    $DOWNLOADER -x --audio-format "$FORMAT" --yes-playlist "$URL"
}

# Function to detect if URL is a playlist
is_playlist() {
    local url="$1"
    
    # YouTube playlist patterns
    if [[ "$url" == *"youtube.com/playlist"* ]] || 
       [[ "$url" == *"youtu.be/playlist"* ]] || 
       [[ "$url" == *"&list="* ]] || 
       [[ "$url" == *"?list="* ]]; then
        return 0
    fi
    
    # SoundCloud playlist patterns
    if [[ "$url" == *"soundcloud.com"*"/sets/"* ]] || 
       [[ "$url" == *"soundcloud.com"*"/playlists/"* ]] || 
       [[ "$url" == *"soundcloud.com"*"/albums/"* ]]; then
        return 0
    fi
    
    # Spotify playlist patterns
    if [[ "$url" == *"open.spotify.com/playlist"* ]] || 
       [[ "$url" == *"open.spotify.com/album"* ]]; then
        return 0
    fi
    
    return 1
}

# Main download logic
if [[ "$URL" == *"youtube.com"* ]] || [[ "$URL" == *"youtu.be"* ]]; then
    if is_playlist "$URL"; then
        download_youtube true
    else
        download_youtube false
    fi
elif [[ "$URL" == *"soundcloud.com"* ]]; then
    if is_playlist "$URL"; then
        download_soundcloud_playlist
    else
        $DOWNLOADER -x --audio-format "$FORMAT" --no-playlist "$URL"
    fi
elif [[ "$URL" == *"open.spotify.com"* ]]; then
    download_spotify
else
    echo "Error: Unsupported URL. Supported platforms: YouTube, SoundCloud, Spotify."
    echo ""
    echo "For YouTube 403 errors, try these options:"
    echo "  $0 \"URL\" \"mp3\" --cookies    (use browser cookies)"
    echo "  $0 \"URL\" \"mp3\" --retry      (aggressive retry)"
    echo "  $0 \"URL\" \"mp3\" --throttle   (slow download)"
    exit 1
fi

echo "Download complete!"
