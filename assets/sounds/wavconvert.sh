#!/bin/bash

# Convert freedesktop sounds
cd freedesktop
for file in *.oga; do
    if [ -f "$file" ]; then
        echo "Converting $file to WAV..."
        ffmpeg -i "$file" -acodec pcm_s16le -ar 44100 -ac 2 "${file%.oga}.wav"
    fi
done

# Convert plasma sounds  
cd ../plasma
for file in *.ogg; do
    if [ -f "$file" ]; then
        echo "Converting $file to WAV..."
        ffmpeg -i "$file" -acodec pcm_s16le -ar 44100 -ac 2 "${file%.ogg}.wav"
    fi
done

echo "Conversion complete!"
