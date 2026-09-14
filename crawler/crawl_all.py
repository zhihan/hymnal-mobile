#!/usr/bin/env python3
"""
Master script to crawl all hymns, convert Chinese hymns, and extract MIDI melodies.

Process:
1. Fetch Chinese hymns (ch, ts) from hymnal.net
2. Fetch English hymns (lb, nt, h, ns) from hymnal.net
3. Fetch English hymns from songbase.life
4. Deduplicate and merge songbase into hymns/
5. Convert Chinese hymns to simplified Chinese
6. Download MIDI tunes and embed melody notes (metadata.melody)
"""

import os
import argparse
import logging
from pathlib import Path

from crawl_hymns import crawl_category, CATEGORY_RANGES
from batch_convert_chinese_hymns import batch_convert_hymns
from songbase_crawler import SongbaseCrawler
from dedup_hymns import merge_all
from extract_midi_notes import MidiExtractionError
from extract_midi_notes import process_directory as extract_midi_notes

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Crawling order: Chinese first, then English
CHINESE_CATEGORIES = ['ch', 'ts']
ENGLISH_CATEGORIES = ['lb', 'nt', 'h', 'ns']


def crawl_all(
    output_dir: str = "hymns",
    songbase_dir: str = "hymns_songbase",
    skip_chinese: bool = False,
    skip_english: bool = False,
    skip_songbase: bool = False,
    skip_convert: bool = False,
    skip_midi: bool = False,
    dry_run: bool = False,
    delay: float = 0.5,
    **crawl_kwargs
) -> dict:
    """
    Execute the full crawl pipeline.

    Args:
        output_dir: Directory to save hymns
        skip_chinese: Skip crawling Chinese hymns
        skip_english: Skip crawling English hymns
        skip_songbase: Skip crawling songbase.life and dedup/merge
        skip_convert: Skip Chinese to simplified conversion
        skip_midi: Skip MIDI tune download and melody note extraction
        dry_run: Show what would be done without executing
        delay: Delay between requests in seconds (also used before each MIDI download)
        **crawl_kwargs: Additional arguments passed to crawl_category

    Returns:
        Dictionary with statistics for each phase
    """
    results = {
        "chinese": [],
        "english": [],
        "songbase": None,
        "dedup": None,
        "conversion": None,
        "midi": None,
    }

    os.makedirs(output_dir, exist_ok=True)

    # Phase 1: Crawl Chinese hymns
    if not skip_chinese:
        print("\n" + "=" * 60)
        print("PHASE 1: Crawling Chinese hymns (ch, ts)")
        print("=" * 60)

        if dry_run:
            for cat in CHINESE_CATEGORIES:
                start, end = CATEGORY_RANGES[cat]
                print(f"  [DRY RUN] Would crawl {cat}: {start} to {end}")
        else:
            for cat in CHINESE_CATEGORIES:
                result = crawl_category(cat, output_dir=output_dir, delay=delay, **crawl_kwargs)
                results["chinese"].append(result)
    else:
        print("\n[SKIPPED] Phase 1: Chinese hymns")

    # Phase 2: Crawl English hymns
    if not skip_english:
        print("\n" + "=" * 60)
        print("PHASE 2: Crawling English hymns (lb, nt, h, ns)")
        print("=" * 60)

        if dry_run:
            for cat in ENGLISH_CATEGORIES:
                start, end = CATEGORY_RANGES[cat]
                print(f"  [DRY RUN] Would crawl {cat}: {start} to {end}")
        else:
            for cat in ENGLISH_CATEGORIES:
                result = crawl_category(cat, output_dir=output_dir, delay=delay, **crawl_kwargs)
                results["english"].append(result)
    else:
        print("\n[SKIPPED] Phase 2: English hymns")

    # Phase 3: Crawl songbase.life
    if not skip_songbase:
        print("\n" + "=" * 60)
        print("PHASE 3: Crawling songbase.life")
        print("=" * 60)

        if dry_run:
            for slug, book_id in SongbaseCrawler.BOOK_MAPPING.items():
                print(f"  [DRY RUN] Would crawl {slug} -> {book_id}")
        else:
            crawler = SongbaseCrawler()
            songbase_results = crawler.crawl_all_books(output_dir=songbase_dir)
            results["songbase"] = songbase_results
    else:
        print("\n[SKIPPED] Phase 3: Songbase.life")

    # Phase 4: Deduplicate and merge songbase into hymns
    if not skip_songbase:
        print("\n" + "=" * 60)
        print("PHASE 4: Deduplicating and merging songbase hymns")
        print("=" * 60)

        if dry_run:
            print(f"  [DRY RUN] Would merge {songbase_dir}/ into {output_dir}/")
        else:
            dedup_result = merge_all(
                hymnal_dir=output_dir,
                songbase_dir=songbase_dir,
            )
            results["dedup"] = dedup_result
    else:
        print("\n[SKIPPED] Phase 4: Songbase dedup/merge")

    # Phase 5: Convert Chinese hymns to simplified
    if not skip_convert:
        print("\n" + "=" * 60)
        print("PHASE 5: Converting Chinese hymns to simplified Chinese")
        print("=" * 60)

        if dry_run:
            print("  [DRY RUN] Would convert ch and ts hymns")
        else:
            result = batch_convert_hymns(
                hymns_dir=output_dir,
                categories=['ch', 'ts'],
                dry_run=False
            )
            results["conversion"] = result
    else:
        print("\n[SKIPPED] Phase 5: Chinese conversion")

    # Phase 6: Download MIDI tunes and embed melody notes. Default-on like
    # every other phase. Note the crawl phases rewrite hymn JSON from
    # scratch, wiping any previously stored melody, so a full run
    # re-downloads every MIDI tune (the version cache in
    # extract_midi_notes only pays off for standalone extractor runs
    # against an existing corpus).
    if not skip_midi:
        print("\n" + "=" * 60)
        print("PHASE 6: Extracting MIDI melody notes")
        print("=" * 60)
        if dry_run:
            print(f"  [DRY RUN] Would process MIDI URLs in {output_dir}/")
        else:
            try:
                results["midi"] = extract_midi_notes(output_dir, delay=delay)
            except MidiExtractionError as error:
                # Fail the build loudly instead of burying the failure in the
                # summary; build_hymns.sh (set -e) stops before copying.
                raise RuntimeError(f"Phase 6 (MIDI extraction) failed: {error}") from error
    else:
        print("\n[SKIPPED] Phase 6: MIDI extraction (--skip-midi)")

    # Final summary
    print("\n" + "=" * 60)
    print("FINAL SUMMARY")
    print("=" * 60)

    if not dry_run:
        # Chinese hymns summary
        total_chinese = sum(r["fetched"] for r in results["chinese"]) if results["chinese"] else 0
        print(f"Chinese hymns fetched: {total_chinese}")
        for r in results["chinese"]:
            print(f"  - {r['category']}: {r['fetched']} fetched, {r['skipped']} skipped")

        # English hymns summary
        total_english = sum(r["fetched"] for r in results["english"]) if results["english"] else 0
        print(f"English hymns fetched: {total_english}")
        for r in results["english"]:
            print(f"  - {r['category']}: {r['fetched']} fetched, {r['skipped']} skipped")

        # Songbase summary
        if results["songbase"]:
            for r in results["songbase"]:
                label = r.get("book_slug", r.get("book_id", "unknown"))
                print(f"Songbase {label}: {r['converted']}/{r['total']} converted, {r['errors']} errors")

        # Dedup summary
        if results["dedup"]:
            d = results["dedup"]
            print(f"Dedup: {d['same']} identical, {d['different']} different, {d['songbase_only']} new")

        # Conversion summary
        if results["conversion"]:
            print(f"Chinese hymns converted: {results['conversion']['success']}")

        if results["midi"]:
            m = results["midi"]
            print(f"MIDI melodies: {m['updated']} updated, {m['errors']} errors")

    print("=" * 60)

    return results


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Crawl all hymns, convert Chinese, and extract MIDI melodies"
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="hymns",
        help="Output directory for hymns (default: hymns)"
    )
    parser.add_argument(
        "--skip-chinese",
        action="store_true",
        help="Skip crawling Chinese hymns (ch, ts)"
    )
    parser.add_argument(
        "--skip-english",
        action="store_true",
        help="Skip crawling English hymns (lb, nt, h, ns)"
    )
    parser.add_argument(
        "--songbase-dir",
        type=str,
        default="hymns_songbase",
        help="Directory for songbase hymns (default: hymns_songbase)"
    )
    parser.add_argument(
        "--skip-songbase",
        action="store_true",
        help="Skip crawling songbase.life and dedup/merge"
    )
    parser.add_argument(
        "--skip-convert",
        action="store_true",
        help="Skip Chinese to simplified conversion"
    )
    parser.add_argument(
        "--skip-midi",
        action="store_true",
        help="Skip MIDI tune download and melody note extraction (on by default)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without executing"
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=50,
        help="Batch size for saving (default: 50)"
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.5,
        help="Delay between requests in seconds (default: 0.5)"
    )

    args = parser.parse_args()

    crawl_all(
        output_dir=args.output_dir,
        songbase_dir=args.songbase_dir,
        skip_chinese=args.skip_chinese,
        skip_english=args.skip_english,
        skip_songbase=args.skip_songbase,
        skip_convert=args.skip_convert,
        skip_midi=args.skip_midi,
        dry_run=args.dry_run,
        batch_size=args.batch_size,
        delay=args.delay,
    )


if __name__ == "__main__":
    main()
