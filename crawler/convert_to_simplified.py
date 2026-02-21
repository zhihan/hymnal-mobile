#!/usr/bin/env python3
"""
Script to convert traditional Chinese characters to simplified Chinese in hymn JSON files.

Usage:
    python convert_to_simplified.py <input_file> [output_file]
    python convert_to_simplified.py hymns/ts_5.json
    python convert_to_simplified.py hymns/ts_5.json hymns/ts_5_simplified.json
"""

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


def convert_json_file(input_path, output_path=None):
    """
    Convert a JSON file from traditional to simplified Chinese.

    Args:
        input_path: Path to input JSON file
        output_path: Path to output JSON file (defaults to overwriting input)

    Returns:
        True if successful, False otherwise
    """
    input_path = Path(input_path)

    if not input_path.exists():
        print(f"Error: Input file '{input_path}' does not exist")
        return False

    if output_path is None:
        output_path = input_path
    else:
        output_path = Path(output_path)

    try:
        # Initialize OpenCC converter (traditional to simplified)
        converter = OpenCC('t2s')  # t2s = Traditional to Simplified

        # Read JSON file
        with open(input_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        # Convert all text to simplified Chinese
        converted_data = convert_dict_to_simplified(data, converter)

        # Write to output file
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(converted_data, f, ensure_ascii=False, indent=2)

        print(f"Successfully converted '{input_path}' to simplified Chinese")
        if output_path != input_path:
            print(f"Output saved to '{output_path}'")
        else:
            print(f"File updated in place")

        return True

    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON file - {e}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False


def main():
    if len(sys.argv) < 2:
        print("Usage: python convert_to_simplified.py <input_file> [output_file]")
        print("\nExamples:")
        print("  python convert_to_simplified.py hymns/ts_5.json")
        print("  python convert_to_simplified.py hymns/ts_5.json hymns/ts_5_simplified.json")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    success = convert_json_file(input_file, output_file)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
