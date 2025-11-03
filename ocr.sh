#!/bin/bash

# OCR script with multiple cropping regions and optional OCRopus normalization
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
CROPPED_IMAGE1="${BASENAME}.crop1.png"
CROPPED_IMAGE2="${BASENAME}.crop2.png"
NORMALIZED_IMAGE1="${BASENAME}.nrm1.png"
NORMALIZED_IMAGE2="${BASENAME}.nrm2.png"

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

# Function to normalize image
normalize_image() {
    local input_image="$1"
    local output_image="$2"
    
    echo "Attempting OCRopus normalization for $input_image..."
    if command -v docker &> /dev/null; then
        # Check if image is tall enough for OCRopus (at least 100 pixels)
        IMAGE_INFO=$(identify "$input_image" 2>/dev/null || echo "")
        if [[ "$IMAGE_INFO" =~ ([0-9]+)x([0-9]+) ]]; then
            WIDTH="${BASH_REMATCH[1]}"
            HEIGHT="${BASH_REMATCH[2]}"
            
            if [ "$HEIGHT" -lt 100 ]; then
                echo "Warning: Image too small for OCRopus (${HEIGHT}px tall, minimum 100px required)"
                echo "Using simple ImageMagick normalization instead..."
                convert "$input_image" -colorspace Gray -normalize "$output_image"
            else
                # Use OCRopus for normalization
                docker run --rm -u $(id -u):$(id -g) \
                    -e HOME=/tmp \
                    -e MPLCONFIGDIR=/tmp/.matplotlib \
                    -v "$WORK_DIR:/output" \
                    kbai/ocropy \
                    ocropus-nlbin "/output/$input_image" -o /output/temp_ocr_output -n

                # Find the normalized image
                NORMALIZED_FILE=$(find "$WORK_DIR/temp_ocr_output" -name "*.bin.png" | head -n 1)

                if [ -n "$NORMALIZED_FILE" ] && [ -f "$NORMALIZED_FILE" ]; then
                    mv "$NORMALIZED_FILE" "$output_image"
                    rm -rf "$WORK_DIR/temp_ocr_output"
                    echo "OCROPus normalized image saved as: $output_image"
                else
                    echo "Warning: OCRopus normalization failed, using ImageMagick fallback"
                    convert "$input_image" -colorspace Gray -normalize "$output_image"
                fi
            fi
        else
            echo "Warning: Could not get image dimensions, using ImageMagick normalization"
            convert "$input_image" -colorspace Gray -normalize "$output_image"
        fi
    else
        echo "Warning: Docker not available, using ImageMagick for normalization"
        convert "$input_image" -colorspace Gray -normalize "$output_image"
    fi
}

# Step 0: Crop images to specified coordinates

# Crop Region 1: 670x1005 to 828x1030 (200x50)
echo "Step 0: Cropping images..."
echo "Region 1: 670x1005 to 828x1030 (200x50 pixels)..."
convert "$INPUT_IMAGE" -crop 200x50+670+1005 "$CROPPED_IMAGE1"

# Crop Region 2: 135x833 to 300x865 (165x32)
echo "Region 2: 135x833 to 300x865 (165x32 pixels)..."
convert "$INPUT_IMAGE" -crop 160x50+140+835 "$CROPPED_IMAGE2"

if [ ! -f "$CROPPED_IMAGE1" ] || [ ! -f "$CROPPED_IMAGE2" ]; then
    echo "Error: Cropping failed"
    exit 1
fi

echo "Cropped images saved as: $CROPPED_IMAGE1, $CROPPED_IMAGE2"
echo ""

# Process Region 1
echo "=== Processing Region 1 ==="

# Step 1: Run Tesseract on cropped image 1
echo "Step 1: Running Tesseract on cropped region 1..."
tesseract "$CROPPED_IMAGE1" "${BASENAME}_crop1" -l rus
echo "Region 1 OCR output: ${BASENAME}_crop1.txt"
echo ""

# Step 2: Normalize image 1
echo "Step 2: Normalizing region 1..."
normalize_image "$CROPPED_IMAGE1" "$NORMALIZED_IMAGE1"
echo ""

# Step 3: Run Tesseract on normalized image 1
echo "Step 3: Running Tesseract on normalized region 1..."
tesseract "$NORMALIZED_IMAGE1" "${BASENAME}_nrm1" -l rus
echo "Region 1 normalized OCR output: ${BASENAME}_nrm1.txt"
echo ""

# Process Region 2
echo "=== Processing Region 2 ==="

# Step 4: Run Tesseract on cropped image 2
echo "Step 4: Running Tesseract on cropped region 2..."
tesseract "$CROPPED_IMAGE2" "${BASENAME}_crop2" -l rus
echo "Region 2 OCR output: ${BASENAME}_crop2.txt"
echo ""

# Step 5: Normalize image 2
echo "Step 5: Normalizing region 2..."
normalize_image "$CROPPED_IMAGE2" "$NORMALIZED_IMAGE2"
echo ""

# Step 6: Run Tesseract on normalized image 2
echo "Step 6: Running Tesseract on normalized region 2..."
tesseract "$NORMALIZED_IMAGE2" "${BASENAME}_nrm2" -l rus
echo "Region 2 normalized OCR output: ${BASENAME}_nrm2.txt"
echo ""

echo "=== Processing Complete ==="
echo "Generated files for Region 1 (670x1005 to 828x1030):"
echo "  - $CROPPED_IMAGE1 (cropped image)"
echo "  - $NORMALIZED_IMAGE1 (normalized image)"
echo "  - ${BASENAME}_crop1.txt (OCR from cropped)"
echo "  - ${BASENAME}_nrm1.txt (OCR from normalized)"
echo ""
echo "Generated files for Region 2 (135x833 to 300x865):"
echo "  - $CROPPED_IMAGE2 (cropped image)"
echo "  - $NORMALIZED_IMAGE2 (normalized image)"
echo "  - ${BASENAME}_crop2.txt (OCR from cropped)"
echo "  - ${BASENAME}_nrm2.txt (OCR from normalized)"