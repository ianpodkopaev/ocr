#!/usr/bin/env python3

import os
import sys
import cv2
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
import pytesseract
from pathlib import Path


def check_dependencies():
    """Check if required Python libraries are installed"""
    try:
        import cv2
        import numpy as np
        from PIL import Image
        import pytesseract
        return True
    except ImportError as e:
        print(f"Error: Missing dependency - {e}")
        print("Please install required packages:")
        print("pip install opencv-python pillow pytesseract")
        return False


def load_image(image_path):
    """Load image using OpenCV"""
    try:
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Could not load image from {image_path}")
        return image
    except Exception as e:
        print(f"Error loading image: {e}")
        sys.exit(1)


def crop_image(image, x, y, width, height):
    """Crop image region"""
    return image[y:y + height, x:x + width]


def save_image(image, output_path):
    """Save image using OpenCV"""
    cv2.imwrite(output_path, image)


def normalize_image_opencv(image):
    """Normalize image using OpenCV methods"""
    # Convert to grayscale
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    else:
        gray = image

    # Apply histogram equalization
    equalized = cv2.equalizeHist(gray)

    # Apply Gaussian blur to reduce noise
    blurred = cv2.GaussianBlur(equalized, (3, 3), 0)

    # Apply adaptive threshold
    normalized = cv2.adaptiveThreshold(
        blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY, 11, 2
    )

    return normalized


def normalize_image_pil(image):
    """Normalize image using PIL methods"""
    # Convert OpenCV image to PIL
    if len(image.shape) == 3:
        pil_image = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
    else:
        pil_image = Image.fromarray(image)

    # Convert to grayscale
    gray = pil_image.convert('L')

    # Enhance contrast
    enhancer = ImageEnhance.Contrast(gray)
    enhanced = enhancer.enhance(2.0)

    # Enhance sharpness
    sharpener = ImageEnhance.Sharpness(enhanced)
    sharpened = sharpener.enhance(2.0)

    # Convert back to OpenCV format
    normalized = cv2.cvtColor(np.array(sharpened), cv2.COLOR_RGB2BGR)
    return normalized


def run_ocr(image, lang='rus'):
    """Run Tesseract OCR on image"""
    try:
        # Convert OpenCV image to PIL for pytesseract
        if len(image.shape) == 3:
            pil_image = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        else:
            pil_image = Image.fromarray(image)

        # Configure tesseract
        config = '--oem 3 --psm 6'
        if lang:
            config += f' -l {lang}'

        text = pytesseract.image_to_string(pil_image, config=config)
        return text.strip()
    except Exception as e:
        print(f"OCR Error: {e}")
        return ""


def process_region(image, region_name, crop_coords, basename):
    """Process a single region (crop, normalize, OCR)"""
    print(f"=== Processing {region_name} ===")

    # Crop image
    x, y, width, height = crop_coords
    cropped = crop_image(image, x, y, width, height)
    cropped_filename = f"./pic/{basename}.{region_name}_cropped.png"
    save_image(cropped, cropped_filename)
    print(f"Cropped image saved as: {cropped_filename}")

    # Run OCR on cropped image
    cropped_ocr = run_ocr(cropped)
    cropped_text_filename = f"./txt/{basename}_{region_name}_cropped.txt"
    with open(cropped_text_filename, 'w', encoding='utf-8') as f:
        f.write(cropped_ocr)
    print(f"Cropped OCR output: {cropped_text_filename}")
    print(f"OCR Text: {cropped_ocr}")
    print()

    # Normalize image (try OpenCV method first)
    normalized = normalize_image_opencv(cropped)
    normalized_filename = f"./pic/{basename}.{region_name}_normalized.png"
    save_image(normalized, normalized_filename)
    print(f"Normalized image saved as: {normalized_filename}")

    # Run OCR on normalized image
    normalized_ocr = run_ocr(normalized)
    normalized_text_filename = f"./txt/{basename}_{region_name}_normalized.txt"
    with open(normalized_text_filename, 'w', encoding='utf-8') as f:
        f.write(normalized_ocr)
    print(f"Normalized OCR output: {normalized_text_filename}")
    print(f"OCR Text: {normalized_ocr}")
    print()

    return {
        'cropped_file': cropped_filename,
        'normalized_file': normalized_filename,
        'cropped_text_file': cropped_text_filename,
        'normalized_text_file': normalized_text_filename,
        'cropped_ocr': cropped_ocr,
        'normalized_ocr': normalized_ocr
    }


def main():


    # if len(sys.argv) != 3 or sys.argv[1] != "run":
    #     print("Usage: python ocr_script.py run <image.jpg>")
    #     sys.exit(1)
    print("Input pic path")
    input_image=input()
    if not os.path.isfile(input_image):
        print(f"Error: File '{input_image}' not found")
        sys.exit(1)

    if not check_dependencies():
        sys.exit(1)

    print("=== OCR Processing ===")
    print(f"Input image: {input_image}")
    print()

    # Get base filename
    basename = Path(input_image).stem

    # Load image
    image = load_image(input_image)

    # Define crop regions
    regions = {
        'region1': {
            'name': 'Region 1 (670x1005 to 828x1030)',
            'coords': (670, 1005, 200, 50)  # x, y, width, height
        },
        'region2': {
            'name': 'Region 2 (135x833 to 300x865)',
            'coords': (140, 835, 160, 50)  # x, y, width, height
        }
    }

    results = {}

    # Process each region
    for region_key, region_info in regions.items():
        results[region_key] = process_region(
            image,
            region_key,
            region_info['coords'],
            basename
        )

    # Print summary
    print("=== Processing Complete ===")
    for region_key, region_info in regions.items():
        result = results[region_key]
        print(f"Generated files for {region_info['name']}:")
        print(f"  - {result['cropped_file']} (cropped image)")
        print(f"  - {result['normalized_file']} (normalized image)")
        print(f"  - {result['cropped_text_file']} (OCR from cropped)")
        print(f"  - {result['normalized_text_file']} (OCR from normalized)")
        print()


if __name__ == "__main__":
    main()