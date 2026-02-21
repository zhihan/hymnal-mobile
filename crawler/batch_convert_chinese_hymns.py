#!/usr/bin/env python3
"""
Batch convert all Chinese hymn files from traditional to simplified Chinese.

This script processes all 'ch' (Chinese Classical Hymns) and 'ts' (Chinese New Hymns)
JSON files in the hymns directory and converts them to simplified Chinese.

Usage:
    python batch_convert_chinese_hymns.py [--dry-run] [--categories ch,ts]
"""

import argparse
import json
import sys
import logging
from pathlib import Path
from opencc import OpenCC

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)


def convert_text_to_simplified(text, converter):
    """Convert traditional Chinese text to simplified Chinese."""
    if not text or not isinstance(text, str):
        return text
    return converter.convert(text)


def convert_dict_to_simplified(data, converter):
    """Recursively convert all string values in a dictionary to simplified Chinese."""
    if isinstance(data, dict):
        return {key: convert_dict_to_simplified(value, converter) for key, value in data.items()}
    elif isinstance(data, list):
        return [convert_dict_to_simplified(item, converter) for item in data]
    elif isinstance(data, str):
        return convert_text_to_simplified(data, converter)
    else:
        return data


def convert_json_file(file_path, converter, dry_run=False):
    """
    Convert a single JSON file from traditional to simplified Chinese.

    Args:
        file_path: Path to the JSON file
        converter: OpenCC converter instance
        dry_run: If True, only show what would be converted without making changes

    Returns:
        True if successful, False otherwise
    """
    try:
        # Read JSON file
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        if dry_run:
            print(f"  [DRY RUN] Would convert: {file_path}")
            return True

        # Convert all text to simplified Chinese
        converted_data = convert_dict_to_simplified(data, converter)

        # Write back to the same file
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(converted_data, f, ensure_ascii=False, indent=2)

        return True

    except json.JSONDecodeError as e:
        print(f"  ERROR: Invalid JSON in {file_path} - {e}")
        return False
    except Exception as e:
        print(f"  ERROR: Failed to convert {file_path} - {e}")
        return False


def batch_convert_hymns(hymns_dir="hymns", categories=None, dry_run=False):
    """
    Batch convert Chinese hymn files to simplified Chinese.

    Args:
        hymns_dir: Directory containing hymn JSON files
        categories: List of categories to process (e.g., ['ch', 'ts'])
        dry_run: If True, only show what would be converted without making changes

    Returns:
        Dictionary with success and failure counts
    """
    hymns_path = Path(hymns_dir)

    if not hymns_path.exists():
        print(f"Error: Directory '{hymns_dir}' does not exist")
        return {"success": 0, "failed": 0, "total": 0}

    # Default to Chinese categories
    if categories is None:
        categories = ['ch', 'ts']

    # Initialize OpenCC converter
    print("Initializing OpenCC converter (Traditional to Simplified)...")
    converter = OpenCC('t2s')

    # Find all matching JSON files
    files_to_process = []
    for category in categories:
        pattern = f"{category}_*.json"
        matching_files = list(hymns_path.glob(pattern))
        files_to_process.extend(matching_files)

    if not files_to_process:
        print(f"No files found for categories: {', '.join(categories)}")
        return {"success": 0, "failed": 0, "total": 0}

    # Sort files for consistent processing order
    files_to_process.sort()

    total = len(files_to_process)
    success = 0
    failed = 0

    print(f"\nFound {total} files to process")
    if dry_run:
        print("DRY RUN MODE - No files will be modified\n")
    else:
        print("Converting files...\n")

    # Process each file
    for i, file_path in enumerate(files_to_process, 1):
        file_name = file_path.name
        if convert_json_file(file_path, converter, dry_run):
            if not dry_run:
                print(f"  [{i}/{total}] ✓ Converted: {file_name}")
            success += 1
        else:
            failed += 1

    # Print summary
    print("\n" + "="*60)
    print("CONVERSION SUMMARY")
    print("="*60)
    print(f"Total files processed: {total}")
    print(f"Successfully converted: {success}")
    print(f"Failed: {failed}")

    if dry_run:
        print("\nDRY RUN completed - no files were modified")
    else:
        print("\nAll conversions completed!")

    return {"success": success, "failed": failed, "total": total}


def main():
    parser = argparse.ArgumentParser(
        description="Batch convert Chinese hymn files from traditional to simplified Chinese"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be converted without making changes"
    )
    parser.add_argument(
        "--categories",
        type=str,
        default="ch,ts",
        help="Comma-separated list of categories to process (default: ch,ts)"
    )
    parser.add_argument(
        "--hymns-dir",
        type=str,
        default="hymns",
        help="Directory containing hymn JSON files (default: hymns)"
    )

    args = parser.parse_args()

    # Parse categories
    categories = [cat.strip() for cat in args.categories.split(',')]

    # Run batch conversion
    result = batch_convert_hymns(
        hymns_dir=args.hymns_dir,
        categories=categories,
        dry_run=args.dry_run
    )

    # Exit with error code if any conversions failed
    sys.exit(0 if result["failed"] == 0 else 1)


if __name__ == "__main__":
    main()
