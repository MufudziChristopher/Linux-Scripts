ffmpeg -f concat -safe 0 -i <(printf "file '$PWD/%s'\n" part*.mp4 | sort) -c copy output.mp4

