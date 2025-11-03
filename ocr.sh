#!/bin/bash

# OCR script with OCRopus normalization
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
NORMALIZED_IMAGE="${BASENAME}.nrm.png"

echo "=== OCR Processing ==="
echo "Input image: $INPUT_IMAGE"
echo ""

# Check if required tools are installed
if ! command -v tesseract &> /dev/null; then
    echo "Error: tesseract is not installed"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "Error: docker is not installed (needed for OCRopus)"
    exit 1
fi

# Get absolute path of input image
INPUT_ABS=$(realpath "$INPUT_IMAGE")
INPUT_DIR=$(dirname "$INPUT_ABS")
INPUT_FILE=$(basename "$INPUT_ABS")
WORK_DIR=$(pwd)

# Step 1: Normalize image using OCRopus via Docker
echo "Step 1: Normalizing image with OCRopus..."
docker run --rm -u $(id -u):$(id -g) \
    -e HOME=/tmp \
    -e MPLCONFIGDIR=/tmp/.matplotlib \
    -v "$INPUT_DIR:/data" \
    -v "$WORK_DIR:/output" \
    kbai/ocropy \
    ocropus-nlbin "/data/$INPUT_FILE" -o /output/temp_ocr_output

# Find the normalized image (OCRopus creates it in a subdirectory)
NORMALIZED_FILE=$(find "$WORK_DIR/temp_ocr_output" -name "*.bin.png" | head -n 1)

if [ -z "$NORMALIZED_FILE" ] || [ ! -f "$NORMALIZED_FILE" ]; then
    echo "Error: Normalization failed, no output file found"
    rm -rf "$WORK_DIR/temp_ocr_output"
    exit 1
fi

# Move normalized image to expected location
mv "$NORMALIZED_FILE" "$NORMALIZED_IMAGE"
rm -rf "$WORK_DIR/temp_ocr_output"

echo "Normalized image saved as: $NORMALIZED_IMAGE"
echo ""

# Step 2: Run Tesseract on original image
echo "Step 2: Running Tesseract on original image..."
tesseract "$INPUT_IMAGE" "${BASENAME}_original" -l rus
echo "Original OCR output: ${BASENAME}_original.txt"
echo ""

# Step 3: Run Tesseract on normalized image
echo "Step 3: Running Tesseract on normalized image..."
tesseract "$NORMALIZED_IMAGE" "${BASENAME}_normalized" -l rus
echo "Normalized OCR output: ${BASENAME}_normalized.txt"
echo ""

echo "=== Processing Complete ==="
echo "Generated files:"
echo "  - $NORMALIZED_IMAGE (normalized image)"
echo "  - ${BASENAME}_original.txt (OCR from original)"
echo "  - ${BASENAME}_normalized.txt (OCR from normalized)"