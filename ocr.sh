#!/bin/bash

# OCR script with cropping and optional OCRopus normalization
# Usage: ./ocr.sh run picture.jpg

set -e

# Check if correct number of arguments
if [ "$#" -ne 2 ] || [ "$1" != "run" ]; then
    echo "Usage: $0 run <image.jpg>"
    exit 1
fi

# Check if input file exists
INPUT_IMAGE="$2"
if [ ! -f "$INPUT_IMAGE" ]; then
    echo "Error: File '$INPUT_IMAGE' not found"
    exit 1
fi

# Get base filename without extension
BASENAME=$(basename "${INPUT_IMAGE%.*}")
CROPPED_IMAGE="${BASENAME}.cropped.png"
NORMALIZED_IMAGE="${BASENAME}.nrm.png"

echo "=== OCR Processing ==="
echo "Input image: $INPUT_IMAGE"
echo ""

# Check if required tools are installed
if ! command -v tesseract &> /dev/null; then
    echo "Error: tesseract is not installed"
    exit 1
fi

if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick (convert) is not installed (needed for cropping)"
    exit 1
fi

# Get absolute path of input image
INPUT_ABS=$(realpath "$INPUT_IMAGE")
INPUT_DIR=$(dirname "$INPUT_ABS")
INPUT_FILE=$(basename "$INPUT_ABS")
WORK_DIR=$(pwd)

# Step 0: Crop image to specified coordinates
echo "Step 0: Cropping image to region 670x1005 to 828x1030..."
convert "$INPUT_IMAGE" -crop 200x50+670+1005 "$CROPPED_IMAGE"

if [ ! -f "$CROPPED_IMAGE" ]; then
    echo "Error: Cropping failed"
    exit 1
fi

echo "Cropped image saved as: $CROPPED_IMAGE"
echo ""

# Step 1: Run Tesseract on cropped image
echo "Step 1: Running Tesseract on cropped image..."
tesseract "$CROPPED_IMAGE" "${BASENAME}_cropped" -l rus
echo "Cropped OCR output: ${BASENAME}_cropped.txt"
echo ""

# Step 2: Try OCRopus normalization only if image is large enough
echo "Step 2: Attempting OCRopus normalization..."
if command -v docker &> /dev/null; then
    # Check if image is tall enough for OCRopus (at least 100 pixels)
    IMAGE_INFO=$(identify "$CROPPED_IMAGE" 2>/dev/null || echo "")
    if [[ "$IMAGE_INFO" =~ ([0-9]+)x([0-9]+) ]]; then
        WIDTH="${BASH_REMATCH[1]}"
        HEIGHT="${BASH_REMATCH[2]}"
        
        if [ "$HEIGHT" -lt 100 ]; then
            echo "Warning: Image too small for OCRopus (${HEIGHT}px tall, minimum 100px required)"
            echo "Skipping OCRopus normalization, using simple ImageMagick normalization instead..."
            
            # Use ImageMagick for basic normalization
            convert "$CROPPED_IMAGE" -colorspace Gray -normalize "$NORMALIZED_IMAGE"
            echo "Basic normalized image saved as: $NORMALIZED_IMAGE"
        else
            # Use OCRopus for normalization
            docker run --rm -u $(id -u):$(id -g) \
                -e HOME=/tmp \
                -e MPLCONFIGDIR=/tmp/.matplotlib \
                -v "$WORK_DIR:/output" \
                kbai/ocropy \
                ocropus-nlbin "/output/$CROPPED_IMAGE" -o /output/temp_ocr_output -n

            # Find the normalized image
            NORMALIZED_FILE=$(find "$WORK_DIR/temp_ocr_output" -name "*.bin.png" | head -n 1)

            if [ -n "$NORMALIZED_FILE" ] && [ -f "$NORMALIZED_FILE" ]; then
                mv "$NORMALIZED_FILE" "$NORMALIZED_IMAGE"
                rm -rf "$WORK_DIR/temp_ocr_output"
                echo "OCROPus normalized image saved as: $NORMALIZED_IMAGE"
            else
                echo "Warning: OCRopus normalization failed, using ImageMagick fallback"
                convert "$CROPPED_IMAGE" -colorspace Gray -normalize "$NORMALIZED_IMAGE"
                echo "Basic normalized image saved as: $NORMALIZED_IMAGE"
            fi
        fi
    else
        echo "Warning: Could not get image dimensions, using ImageMagick normalization"
        convert "$CROPPED_IMAGE" -colorspace Gray -normalize "$NORMALIZED_IMAGE"
        echo "Basic normalized image saved as: $NORMALIZED_IMAGE"
    fi
else
    echo "Warning: Docker not available, using ImageMagick for normalization"
    convert "$CROPPED_IMAGE" -colorspace Gray -normalize "$NORMALIZED_IMAGE"
    echo "Basic normalized image saved as: $NORMALIZED_IMAGE"
fi

echo ""

# Step 3: Run Tesseract on normalized image
echo "Step 3: Running Tesseract on normalized image..."
tesseract "$NORMALIZED_IMAGE" "${BASENAME}_normalized" -l rus
echo "Normalized OCR output: ${BASENAME}_normalized.txt"
echo ""

echo "=== Processing Complete ==="
echo "Generated files:"
echo "  - $CROPPED_IMAGE (cropped image)"
echo "  - $NORMALIZED_IMAGE (normalized image)"
echo "  - ${BASENAME}_cropped.txt (OCR from cropped)"
echo "  - ${BASENAME}_normalized.txt (OCR from normalized)"