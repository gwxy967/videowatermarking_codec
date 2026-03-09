#!/bin/bash
# Universal Video Encode/Decode Script - FIXED RESOLUTION (256x256)
# Function: Processes videos using params passed from run_all.sh

# 1. Check arguments
if [ $# -lt 5 ]; then
    echo "Usage: $0 <input_folder> <output_folder> <codec_type> <encode_params> <extension>"
    exit 1
fi

INPUT_DIR="$1"
OUTPUT_DIR="$2"
CODEC_TYPE="$3"
USER_PARAMS="$4" 
OUTPUT_EXT="$5"

# 2. Handle Extension (Robust Check)
if [ -z "$OUTPUT_EXT" ]; then
    echo "Error: Output extension not specified."
    exit 1
fi

# Ensure extension has a dot (e.g., "mp4" -> ".mp4")
if [[ "$OUTPUT_EXT" != .* ]]; then
    FINAL_EXT=".$OUTPUT_EXT"
else
    FINAL_EXT="$OUTPUT_EXT"
fi

# 3. Validation
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input folder does not exist: $INPUT_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 4. Define Resolution Scaling
# Using strict scaling to 256x256.
# setsar=1 ensures Square Pixels to avoid stretching issues.
SCALE_FILTER="-vf scale=512:512,setsar=1"

echo "Starting Batch Processing..."
echo "Mode: $CODEC_TYPE"
echo "Resolution: 512x512 (Forced)"
echo "Output Format: $FINAL_EXT"
echo "--------------------------------------------------------"

# 5. Define Base Codec Flags
# [Critical Fix]: Added "-ar 48000" for ProRes/DNxHD to prevent audio stream errors.

case "$CODEC_TYPE" in
    h264)
        BASE_FLAGS="-c:v libx264 -movflags +faststart"
        AUDIO_FLAGS="-c:a aac -b:a 128k"
        ;;
    h265)
        BASE_FLAGS="-c:v libx265 -tag:v hvc1"
        AUDIO_FLAGS="-c:a aac -b:a 128k"
        ;;
    prores)
        BASE_FLAGS="-c:v prores_ks"
        # ProRes usually mandates 48kHz PCM audio
        AUDIO_FLAGS="-c:a pcm_s16le -ar 48000"
        ;;
    dnxhd)
        # DNxHD/HR strongly prefers 48kHz PCM audio
        BASE_FLAGS="-c:v dnxhd"
        AUDIO_FLAGS="-c:a pcm_s16le -ar 48000"
        ;;
    vp9)
        BASE_FLAGS="-c:v libvpx-vp9"
        AUDIO_FLAGS="-c:a libopus"
        ;;
    av1)
        BASE_FLAGS="-c:v libsvtav1"
        AUDIO_FLAGS="-c:a aac -b:a 128k"
        ;;
    *)
        echo "Error: Unknown codec type '$CODEC_TYPE'"
        exit 1
        ;;
esac

# 6. Processing Loop

# Find all common video formats
find "$INPUT_DIR" -type f \( -name "*.mp4" -o -name "*.mov" -o -name "*.mkv" -o -name "*.webm" -o -name "*.avi" \) | while IFS= read -r input_video; do
    
    filename=$(basename -- "$input_video")
    parent_dir_path=$(dirname "$input_video")
    parent_dir_name=$(basename "$parent_dir_path")
    
    # Robust filename parsing: Extract filename without extension (handles multiple dots correctly)
    filename_no_ext="${filename%.*}"
    
    # Naming convention: ParentDir_OriginalName.ext
    new_filename="${parent_dir_name}_${filename_no_ext}${FINAL_EXT}"
    output_video="$OUTPUT_DIR/$new_filename"

    echo "Processing: $filename -> 512x512 -> $new_filename"

    # Execute FFmpeg
    # Note: We do NOT quote $USER_PARAMS so that multiple flags (like -crf 23 -preset fast) are split correctly.
    # Added "-y" to overwrite output without asking.
    # Added "-strict -2" for compatibility with older FFmpeg versions/codecs.
    
    ffmpeg -v error -i "$input_video" \
        $SCALE_FILTER \
        $BASE_FLAGS \
        $USER_PARAMS \
        $AUDIO_FLAGS \
        -strict -2 \
        -y \
        "$output_video" < /dev/null

    if [ $? -eq 0 ]; then
        echo " -> [OK]"
    else
        echo " -> [FAILED] Error processing $filename"
        # Delete 0-byte files if ffmpeg failed but created a touch file
        if [ -f "$output_video" ] && [ ! -s "$output_video" ]; then
            rm "$output_video"
            echo "    (Deleted empty output file)"
        fi
    fi
done

echo "========================================================"
echo "Batch finished for $CODEC_TYPE."