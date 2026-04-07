#!/usr/bin/env python3
"""
Deduplication and merge script for hymnal data from multiple sources.

Compares hymns from hymnal.net and songbase.life, merging them into
a single file per hymn. If lyrics are identical, keeps the hymnal.net
version (richer metadata). If different, adds the songbase version
as an alternate_version.

Only h_*.json files are deduped (same numbering between sources).
sb_*.json files (songbase-only songs) are copied as-is without dedup.
"""

import json
import os
import re
import logging
import unicodedata
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


def normalize_lyrics(hymn_data: dict) -> str:
    """
    Extract and normalize lyrics text from a hymn JSON for comparison.

    Strips chords, punctuation, whitespace, and normalizes unicode
    so that minor formatting differences don't cause false mismatches.
    """
    texts = []
    for verse in hymn_data.get('verses', []):
        for line in verse.get('lines', []):
            for segment in line.get('segments', []):
                text = segment.get('text', '')
                if text:
                    texts.append(text)

    combined = ' '.join(texts)

    # Normalize unicode (curly quotes, em-dashes, etc.)
    combined = unicodedata.normalize('NFKC', combined)

    # Replace common typographic variants
    combined = combined.replace('\u2019', "'")  # right single quote
    combined = combined.replace('\u2018', "'")  # left single quote
    combined = combined.replace('\u201c', '"')  # left double quote
    combined = combined.replace('\u201d', '"')  # right double quote
    combined = combined.replace('\u2014', '-')  # em dash
    combined = combined.replace('\u2013', '-')  # en dash

    # Lowercase and strip punctuation
    combined = combined.lower()
    combined = re.sub(r'[^\w\s]', '', combined)

    # Collapse whitespace
    combined = re.sub(r'\s+', ' ', combined).strip()

    return combined


def are_lyrics_same(hymn_a: dict, hymn_b: dict) -> bool:
    """Compare two hymns by normalized lyrics text."""
    return normalize_lyrics(hymn_a) == normalize_lyrics(hymn_b)


def merge_versions(
    hymnal_net_data: dict,
    songbase_data: dict,
) -> dict:
    """
    Merge hymnal.net and songbase versions of the same hymn.

    If lyrics are the same, returns hymnal.net version unchanged.
    If different, returns hymnal.net version with songbase added
    as an alternate version.
    """
    if are_lyrics_same(hymnal_net_data, songbase_data):
        return hymnal_net_data

    # Lyrics differ — add songbase as alternate version
    result = dict(hymnal_net_data)
    alternate = {
        "source": "songbase",
        "title": songbase_data.get("title", ""),
        "url": songbase_data.get("url", ""),
        "verses": songbase_data.get("verses", []),
        "metadata": songbase_data.get("metadata", {}),
    }

    existing_alternates = result.get("alternate_versions", [])
    # Don't duplicate if songbase alternate already exists
    if not any(v.get("source") == "songbase" for v in existing_alternates):
        existing_alternates.append(alternate)

    result["alternate_versions"] = existing_alternates
    return result


def merge_all(
    hymnal_dir: str = "hymns",
    songbase_dir: str = "hymns_songbase",
    output_dir: Optional[str] = None,
) -> dict:
    """
    Merge all songbase hymns into the hymnal directory.

    - h_*.json: dedup by filename (same numbering between sources)
    - sb_*.json: copy as-is (no dedup, separate songbase catalog)

    Args:
        hymnal_dir: Directory with hymnal.net hymn files.
        songbase_dir: Directory with songbase hymn files.
        output_dir: Output directory. If None, writes to hymnal_dir in-place.

    Returns:
        Statistics dict: {same, different, songbase_only, errors, total}.
    """
    if output_dir is None:
        output_dir = hymnal_dir

    hymnal_path = Path(hymnal_dir)
    songbase_path = Path(songbase_dir)
    output_path = Path(output_dir)

    os.makedirs(output_dir, exist_ok=True)

    if not songbase_path.exists():
        logger.warning(f"Songbase directory not found: {songbase_dir}")
        return {"same": 0, "different": 0, "songbase_only": 0, "errors": 0, "total": 0}

    songbase_files = sorted(songbase_path.glob("*.json"))
    stats = {"same": 0, "different": 0, "songbase_only": 0, "errors": 0, "total": len(songbase_files)}

    print(f"\n{'=' * 60}")
    print(f"Merging songbase hymns into {output_dir}")
    print(f"{'=' * 60}")

    for sb_file in songbase_files:
        out_file = output_path / sb_file.name

        try:
            with open(sb_file, 'r', encoding='utf-8') as f:
                songbase_data = json.load(f)

            if sb_file.name.startswith('sb_'):
                # sb_* files: copy as-is, no dedup
                if "metadata" not in songbase_data:
                    songbase_data["metadata"] = {}
                songbase_data["metadata"]["source"] = "songbase"

                with open(out_file, 'w', encoding='utf-8') as f:
                    json.dump(songbase_data, f, ensure_ascii=False, indent=2)

                stats["songbase_only"] += 1
            else:
                # h_* files: dedup by filename
                hymnal_file = hymnal_path / sb_file.name

                if hymnal_file.exists():
                    with open(hymnal_file, 'r', encoding='utf-8') as f:
                        hymnal_data = json.load(f)

                    merged = merge_versions(hymnal_data, songbase_data)

                    if "alternate_versions" in merged:
                        stats["different"] += 1
                        logger.info(f"  DIFFERENT: {sb_file.name}")
                    else:
                        stats["same"] += 1

                    with open(out_file, 'w', encoding='utf-8') as f:
                        json.dump(merged, f, ensure_ascii=False, indent=2)
                else:
                    # Songbase-only h_* hymn
                    if "metadata" not in songbase_data:
                        songbase_data["metadata"] = {}
                    songbase_data["metadata"]["source"] = "songbase"

                    with open(out_file, 'w', encoding='utf-8') as f:
                        json.dump(songbase_data, f, ensure_ascii=False, indent=2)

                    stats["songbase_only"] += 1
                    logger.info(f"  NEW: {sb_file.name} (songbase only)")

        except Exception as e:
            logger.error(f"  ERROR: {sb_file.name}: {e}")
            stats["errors"] += 1

    print(f"\n  Total songbase files: {stats['total']}")
    print(f"  Identical lyrics (kept hymnal.net): {stats['same']}")
    print(f"  Different lyrics (added alternate): {stats['different']}")
    print(f"  Songbase-only (new hymns): {stats['songbase_only']}")
    print(f"  Errors: {stats['errors']}")

    return stats


def main():
    """CLI entry point."""
    import argparse

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    parser = argparse.ArgumentParser(
        description="Deduplicate and merge hymns from hymnal.net and songbase.life"
    )
    parser.add_argument(
        "--hymnal-dir",
        type=str,
        default="hymns",
        help="Directory with hymnal.net hymns (default: hymns)"
    )
    parser.add_argument(
        "--songbase-dir",
        type=str,
        default="hymns_songbase",
        help="Directory with songbase hymns (default: hymns_songbase)"
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default=None,
        help="Output directory (default: same as hymnal-dir)"
    )

    args = parser.parse_args()
    merge_all(
        hymnal_dir=args.hymnal_dir,
        songbase_dir=args.songbase_dir,
        output_dir=args.output_dir,
    )


if __name__ == "__main__":
    main()
