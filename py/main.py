# main.py
from ocr import OCRProcessor
import os


def main():
    # Initialize OCR processor
    ocr_processor = OCRProcessor()

    # Define regions for each field you want to scan
    # You'll need to adjust these coordinates based on your document layout
    field_regions = {
        'fname': (160, 695, 880, 50),  # (x, y, width, height) for file name field
        'date': (183, 585, 300, 50),  # for date field
        'departam': (267, 555, 620, 50),  # for departamment field
        'unp': (130,834, 170, 50)
    }

    # Process a document
    image_path = "./pic/img007.jpg"

    # First, visualize the regions to make sure they're correct
    print("Visualizing field regions...")
    ocr_processor.visualize_field_regions(image_path, field_regions)

    # Process the document and save to database
    print("\nExtracting fields from document...")
    scan_id, extracted_data = ocr_processor.process_and_save_document(
        image_path, field_regions
    )

    if scan_id:
        print(f"\nSuccess! Scan saved with ID: {scan_id}")
        print("Extracted data:")
        for field, value in extracted_data.items():
            print(f"  {field}: {value}")

        # Display all records in database
        print("\nAll scans in database:")
        all_scans = ocr_processor.db.get_all_scans()
        for scan in all_scans:
            print(f"ID: {scan[0]}")
            print(f"File Name: {scan[1]}")
            print(f"Date: {scan[2]}")
            print(f"Departament: {scan[3]}")
            print(f"Scan Date: {scan[4]}")
            print(f"UNP: {scan[5]}")
            print("-" * 50)


if __name__ == "__main__":
    main()