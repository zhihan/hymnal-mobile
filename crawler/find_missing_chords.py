#!/usr/bin/env python3
"""
Scans hymns in the hymns/ directory for missing chords and copies them
to hymns_manual/ directory for manual editing.
"""

import json
import os
import shutil
from pathlib import Path


def has_chords(hymn_data):
    """
    Check if a hymn has any chords.

    Args:
        hymn_data: Parsed hymn JSON dictionary

    Returns:
        bool: True if hymn has at least one non-empty chord, False otherwise
    """
    verses = hymn_data.get('verses', [])

    for verse in verses:
        lines = verse.get('lines', [])
        for line in lines:
            segments = line.get('segments', [])
            for segment in segments:
                chord = segment.get('chord', '').strip()
                if chord:  # Found a non-empty chord
                    return True

    return False


def scan_hymns_for_missing_chords(hymns_dir='hymns', manual_dir='hymns_manual'):
    """
    Scan all hymns and copy those missing chords to manual directory.

    Args:
        hymns_dir: Directory containing hymn JSON files
        manual_dir: Directory where manually edited hymns are stored
    """
    hymns_path = Path(hymns_dir)
    manual_path = Path(manual_dir)

    if not hymns_path.exists():
        print(f"Error: {hymns_dir} directory not found")
        return

    # Create manual directory if it doesn't exist
    manual_path.mkdir(exist_ok=True)

    # Find all JSON files
    json_files = list(hymns_path.glob('*.json'))
    print(f"Scanning {len(json_files)} hymn files...\n")

    missing_chords = []
    errors = []

    for json_file in sorted(json_files):
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                hymn_data = json.load(f)

            if not has_chords(hymn_data):
                missing_chords.append(json_file.name)

                # Copy to manual directory if not already there
                dest_path = manual_path / json_file.name
                if not dest_path.exists():
                    shutil.copy2(json_file, dest_path)
                    print(f"✓ Copied {json_file.name} to {manual_dir}/")
                else:
                    print(f"⊘ Skipped {json_file.name} (already in {manual_dir}/)")

        except Exception as e:
            errors.append((json_file.name, str(e)))
            print(f"✗ Error processing {json_file.name}: {e}")

    # Print summary
    print(f"\n{'='*60}")
    print(f"SUMMARY")
    print(f"{'='*60}")
    print(f"Total hymns scanned: {len(json_files)}")
    print(f"Hymns missing chords: {len(missing_chords)}")
    print(f"Errors encountered: {len(errors)}")

    if missing_chords:
        print(f"\nHymns missing chords:")
        for filename in missing_chords:
            print(f"  - {filename}")

    if errors:
        print(f"\nErrors:")
        for filename, error in errors:
            print(f"  - {filename}: {error}")


if __name__ == '__main__':
    scan_hymns_for_missing_chords()
