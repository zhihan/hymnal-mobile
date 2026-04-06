#!/usr/bin/env python3
"""
Master script to crawl all hymns, convert Chinese hymns, and apply manual edits.

Process:
1. Fetch Chinese hymns (ch, ts) from hymnal.net
2. Fetch English hymns (lb, nt, h, ns) from hymnal.net
3. Fetch English hymns from songbase.life
4. Deduplicate and merge songbase into hymns/
5. Convert Chinese hymns to simplified Chinese
6. Copy manual edits from hymns_manual/ to hymns/
"""

import os
import shutil
import argparse
import logging
from pathlib import Path

from crawl_hymns import crawl_category, CATEGORY_RANGES
from batch_convert_chinese_hymns import batch_convert_hymns
from songbase_crawler import SongbaseCrawler
from dedup_hymns import merge_all

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Crawling order: Chinese first, then English
CHINESE_CATEGORIES = ['ch', 'ts']
ENGLISH_CATEGORIES = ['lb', 'nt', 'h', 'ns']


def copy_manual_edits(manual_dir: str = "hymns_manual", hymns_dir: str = "hymns") -> dict:
    """
    Copy files from hymns_manual/ to hymns/, overwriting existing files.

    Args:
        manual_dir: Directory containing manually edited hymns
        hymns_dir: Target directory for hymns

    Returns:
        Dictionary with statistics: {copied, total}
    """
    manual_path = Path(manual_dir)
    hymns_path = Path(hymns_dir)

    if not manual_path.exists():
        print(f"\nNo manual edits directory found ({manual_dir})")
        return {"copied": 0, "total": 0}

    # Find all JSON files in manual directory
    manual_files = list(manual_path.glob("*.json"))

    if not manual_files:
        print(f"\nNo manual edit files found in {manual_dir}")
        return {"copied": 0, "total": 0}

    print(f"\n{'=' * 60}")
    print(f"Copying manual edits from {manual_dir}/ to {hymns_dir}/")
    print(f"{'=' * 60}")

    copied = 0
    for file_path in sorted(manual_files):
        dest_path = hymns_path / file_path.name
        shutil.copy2(file_path, dest_path)
        print(f"  ✓ Copied: {file_path.name}")
        copied += 1

    print(f"\n  Total copied: {copied} files")
    return {"copied": copied, "total": len(manual_files)}


def crawl_all(
    output_dir: str = "hymns",
    manual_dir: str = "hymns_manual",
    songbase_dir: str = "hymns_songbase",
    skip_chinese: bool = False,
    skip_english: bool = False,
    skip_songbase: bool = False,
    skip_convert: bool = False,
    skip_manual: bool = False,
    dry_run: bool = False,
    **crawl_kwargs
) -> dict:
    """
    Execute the full crawl pipeline.

    Args:
        output_dir: Directory to save hymns
        manual_dir: Directory containing manual edits
        skip_chinese: Skip crawling Chinese hymns
        skip_english: Skip crawling English hymns
        skip_convert: Skip Chinese to simplified conversion
        skip_manual: Skip copying manual edits
        dry_run: Show what would be done without executing
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
        "manual": None,
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
                result = crawl_category(cat, output_dir=output_dir, **crawl_kwargs)
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
                result = crawl_category(cat, output_dir=output_dir, **crawl_kwargs)
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

    # Phase 6: Copy manual edits
    if not skip_manual:
        print("\n" + "=" * 60)
        print("PHASE 6: Applying manual edits")
        print("=" * 60)

        if dry_run:
            manual_path = Path(manual_dir)
            if manual_path.exists():
                files = list(manual_path.glob("*.json"))
                print(f"  [DRY RUN] Would copy {len(files)} files from {manual_dir}/")
            else:
                print(f"  [DRY RUN] No manual directory found")
        else:
            result = copy_manual_edits(manual_dir=manual_dir, hymns_dir=output_dir)
            results["manual"] = result
    else:
        print("\n[SKIPPED] Phase 6: Manual edits")

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
                print(f"Songbase {r['book_slug']}: {r['converted']}/{r['total']} converted, {r['errors']} errors")

        # Dedup summary
        if results["dedup"]:
            d = results["dedup"]
            print(f"Dedup: {d['same']} identical, {d['different']} different, {d['songbase_only']} new")

        # Conversion summary
        if results["conversion"]:
            print(f"Chinese hymns converted: {results['conversion']['success']}")

        # Manual edits summary
        if results["manual"]:
            print(f"Manual edits applied: {results['manual']['copied']}")

    print("=" * 60)

    return results


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Crawl all hymns, convert Chinese, and apply manual edits"
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="hymns",
        help="Output directory for hymns (default: hymns)"
    )
    parser.add_argument(
        "--manual-dir",
        type=str,
        default="hymns_manual",
        help="Directory containing manual edits (default: hymns_manual)"
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
        "--skip-manual",
        action="store_true",
        help="Skip applying manual edits"
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
        manual_dir=args.manual_dir,
        songbase_dir=args.songbase_dir,
        skip_chinese=args.skip_chinese,
        skip_english=args.skip_english,
        skip_songbase=args.skip_songbase,
        skip_convert=args.skip_convert,
        skip_manual=args.skip_manual,
        dry_run=args.dry_run,
        batch_size=args.batch_size,
        delay=args.delay,
    )


if __name__ == "__main__":
    main()
