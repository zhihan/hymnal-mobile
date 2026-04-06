#!/usr/bin/env python3
"""
Deduplication and merge script for hymnal data from multiple sources.

Compares hymns from hymnal.net and songbase.life, merging them into
a single file per hymn. If lyrics are identical, keeps the hymnal.net
version (richer metadata). If different, adds the songbase version
as an alternate_version.

For books where numbering differs between sources (e.g., ns/blue_songbook),
matching is done by normalized title instead of filename. Unmatched
songbase songs are assigned new numbers starting from an offset.
"""

import json
import os
import re
import logging
import unicodedata
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# Books where songbase uses different numbering than hymnal.net.
# These need title-based matching instead of filename-based matching.
TITLE_MATCH_BOOKS = {'ns'}

# Songbase-only songs in title-matched books get numbers starting at this offset
# plus their original songbase book number, to avoid colliding with hymnal.net numbers.
SONGBASE_NUMBER_OFFSET = 2000


def normalize_title(title: str) -> str:
    """Normalize a title for matching: lowercase, strip punctuation, collapse whitespace."""
    t = unicodedata.normalize('NFKC', title)
    t = t.replace('\u2019', "'").replace('\u2018', "'")
    t = t.replace('\u201c', '"').replace('\u201d', '"')
    t = t.replace('\u2014', '-').replace('\u2013', '-')
    t = t.lower()
    t = re.sub(r'[^\w\s]', '', t)
    t = re.sub(r'\s+', ' ', t).strip()
    return t


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
    }

    existing_alternates = result.get("alternate_versions", [])
    # Don't duplicate if songbase alternate already exists
    if not any(v.get("source") == "songbase" for v in existing_alternates):
        existing_alternates.append(alternate)

    result["alternate_versions"] = existing_alternates
    return result


def _build_title_index(hymnal_path: Path, book_id: str) -> dict:
    """
    Build a normalized-title -> filename index for all hymnal.net
    files in a given book.

    Returns:
        Dict mapping normalized_title -> (filename, hymn_data).
    """
    index = {}
    for f in hymnal_path.glob(f"{book_id}_*.json"):
        try:
            with open(f, 'r', encoding='utf-8') as fh:
                data = json.load(fh)
            title = normalize_title(data.get('title', ''))
            if title:
                index[title] = (f.name, data)
        except Exception as e:
            logger.warning(f"Error reading {f.name} for title index: {e}")
    return index


def _merge_title_matched(
    hymnal_path: Path,
    songbase_path: Path,
    output_path: Path,
    book_id: str,
) -> dict:
    """
    Merge songbase files for a book that needs title-based matching.

    Matched songs get merged as alternate versions on the hymnal.net file.
    Unmatched songs get saved with offset numbering.

    Returns:
        Stats dict.
    """
    songbase_files = sorted(songbase_path.glob(f"{book_id}_*.json"))
    stats = {"same": 0, "different": 0, "songbase_only": 0, "errors": 0, "total": len(songbase_files)}

    # Build title index from hymnal.net files
    title_index = _build_title_index(hymnal_path, book_id)
    logger.info(f"  Title index: {len(title_index)} hymnal.net {book_id} hymns indexed")

    matched_hymnal_files = set()

    for sb_file in songbase_files:
        try:
            with open(sb_file, 'r', encoding='utf-8') as f:
                songbase_data = json.load(f)

            sb_title = normalize_title(songbase_data.get('title', ''))

            if sb_title and sb_title in title_index:
                # Title match found — merge into the hymnal.net file
                hymnal_filename, hymnal_data = title_index[sb_title]
                matched_hymnal_files.add(hymnal_filename)

                merged = merge_versions(hymnal_data, songbase_data)

                if "alternate_versions" in merged:
                    stats["different"] += 1
                    logger.info(f"  DIFFERENT: {sb_file.name} -> {hymnal_filename}")
                else:
                    stats["same"] += 1

                out_file = output_path / hymnal_filename
                with open(out_file, 'w', encoding='utf-8') as f:
                    json.dump(merged, f, ensure_ascii=False, indent=2)
            else:
                # No match — save as songbase-only with offset number
                # Extract the songbase book number from filename
                match = re.match(rf'{book_id}_(\d+)\.json', sb_file.name)
                if match:
                    sb_number = int(match.group(1))
                    new_number = sb_number + SONGBASE_NUMBER_OFFSET
                    new_filename = f"{book_id}_{new_number}.json"
                else:
                    new_filename = sb_file.name

                if "metadata" not in songbase_data:
                    songbase_data["metadata"] = {}
                songbase_data["metadata"]["source"] = "songbase"

                out_file = output_path / new_filename
                with open(out_file, 'w', encoding='utf-8') as f:
                    json.dump(songbase_data, f, ensure_ascii=False, indent=2)

                stats["songbase_only"] += 1
                logger.info(f"  NEW: {sb_file.name} -> {new_filename} (songbase only)")

        except Exception as e:
            logger.error(f"  ERROR: {sb_file.name}: {e}")
            stats["errors"] += 1

    return stats


def merge_all(
    hymnal_dir: str = "hymns",
    songbase_dir: str = "hymns_songbase",
    output_dir: Optional[str] = None,
) -> dict:
    """
    Merge all songbase hymns into the hymnal directory.

    For each songbase file:
    - If the book uses title-based matching (e.g., ns): match by title
    - Otherwise: match by filename (same numbering between sources)

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

    # Identify which book IDs need title matching
    title_match_book_ids = set()
    filename_match_files = []
    for sb_file in songbase_files:
        match = re.match(r'([a-z]+)_\d+\.json', sb_file.name)
        if match:
            book_id = match.group(1)
            if book_id in TITLE_MATCH_BOOKS:
                title_match_book_ids.add(book_id)
            else:
                filename_match_files.append(sb_file)
        else:
            filename_match_files.append(sb_file)

    # Process title-matched books
    for book_id in sorted(title_match_book_ids):
        print(f"\n  Merging {book_id} (title-based matching)...")
        book_stats = _merge_title_matched(hymnal_path, songbase_path, output_path, book_id)
        for key in stats:
            if key != "total":
                stats[key] += book_stats[key]

    # Process filename-matched files
    for sb_file in filename_match_files:
        hymnal_file = hymnal_path / sb_file.name
        out_file = output_path / sb_file.name

        try:
            with open(sb_file, 'r', encoding='utf-8') as f:
                songbase_data = json.load(f)

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
                # Songbase-only hymn — add source marker and copy
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
