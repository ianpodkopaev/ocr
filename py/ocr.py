# ocr.py
import cv2
import pytesseract
import os
import re
from db import ScanDatabase


class OCRProcessor:
    def __init__(self, db_path='./db/scans.db'):
        self.db = ScanDatabase(db_path)

    def crop_region(self, image, x, y, w, h):
        """Crop a specific region from the image"""
        return image[y:y + h, x:x + w]

    def preprocess_image(self, image):
        """Preprocess image to improve OCR accuracy"""
        # Convert to grayscale
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        # Apply threshold to get binary image
        _, thresh = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)

        return thresh

    def extract_text_from_region(self, image, region_coords):
        """Extract text from a specific region with preprocessing"""
        x, y, w, h = region_coords
        cropped_region = self.crop_region(image, x, y, w, h)

        # Preprocess the cropped region
        processed_region = self.preprocess_image(cropped_region)

        # Perform OCR with custom configuration
        custom_config = r'--oem 3 --psm 6 -l rus'
        ocr_text = pytesseract.image_to_string(processed_region, config=custom_config)

        return ocr_text.strip()

    def clean_extracted_text(self, text):
        """Clean and format extracted text"""
        # Remove extra whitespace and newlines
        cleaned = ' '.join(text.split())

        # Remove special characters but keep basic punctuation
        cleaned = re.sub(r'[^\w\s\-/:.()]', '', cleaned)

        return cleaned

    def process_document_fields(self, image_path, field_regions):
        """
        Process specific fields from a document image

        Args:
            image_path: Path to the image file
            field_regions: Dictionary defining regions for each field
                         {'fname': (x,y,w,h), 'date': (x,y,w,h), 'departam': (x,y,w,h)}

        Returns:
            Dictionary with cleaned extracted text for each field
        """
        try:
            # Load the image
            image = cv2.imread(image_path)
            if image is None:
                print(f"Error: Could not load image from {image_path}")
                return None

            results = {}

            # Process each field region
            for field_name, region_coords in field_regions.items():
                extracted_text = self.extract_text_from_region(image, region_coords)
                cleaned_text = self.clean_extracted_text(extracted_text)
                results[field_name] = cleaned_text

                print(f"Extracted {field_name}: '{cleaned_text}'")

            return results

        except Exception as e:
            print(f"Error processing image: {e}")
            return None

    def process_and_save_document(self, image_path, field_regions):
        """
        Complete workflow: extract fname, date, departam and save to database
        """
        # Extract fields from the image
        extracted_data = self.process_document_fields(image_path, field_regions)

        if extracted_data and all(key in extracted_data for key in ['fname', 'date', 'departam', 'unp']):
            # Get the extracted values
            fname = extracted_data['fname']
            date = extracted_data['date']
            departam = extracted_data['departam']
            unp = extracted_data['unp']



            # Save to database
            scan_id = self.db.insert_scan(fname, date, departam, unp)
            print(f"Document scan saved to database with ID: {scan_id}")

            return scan_id, extracted_data
        else:
            print("Failed to extract required fields from image")
            return None, extracted_data

    def visualize_field_regions(self, image_path, field_regions, output_path="./pic/document_with_fields.png"):
        """Visualize where field regions are located on the document"""
        image = cv2.imread(image_path)

        # Define colors for different fields
        colors = {
            'fname': (0, 255, 0),  # Green
            'date': (255, 0, 0),  # Blue
            'departam': (0, 0, 255),  # Red
            'unp': (0,0,0) #black
        }

        for field_name, (x, y, w, h) in field_regions.items():
            color = colors.get(field_name, (255, 255, 0))  # Yellow for unknown fields
            # Draw rectangle around each field region
            cv2.rectangle(image, (x, y), (x + w, y + h), color, 2)
            cv2.putText(image, field_name, (x, y - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

        # Save the image with field regions
        cv2.imwrite(output_path, image)
        print(f"Field regions visualization saved to: {output_path}")