#!/usr/bin/env python3
"""
Consolidated hymn crawling module.

Provides a single function to crawl hymns from any supported category.
Replaces the separate crawl_*.py and fetch_*.py scripts.
"""

import os
import time
import logging
from hymnal_crawler import HymnalCrawler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Default ranges for each category
CATEGORY_RANGES = {
    'ch': (1, 800),      # Chinese Classical Hymns (大本)
    'ts': (1, 1000),     # Chinese New Hymns (補充本)
    'h': (1, 1400),      # English Hymns
    'ns': (1, 1200),     # New Songs
    'lb': (1, 100),      # New Songs (lb variant, English)
    'nt': (1, 1400),     # New Tune (English)
}

# Language mapping for URL construction
CATEGORY_LANGUAGES = {
    'ch': 'cn',
    'ts': 'cn',
    'h': 'en',
    'ns': 'en',
    'lb': 'en',
    'nt': 'en',
}


def crawl_category(
    category: str,
    start: int = None,
    end: int = None,
    output_dir: str = "hymns",
    batch_size: int = 50,
    delay: float = 0.5,
    fetch_related: bool = None,
) -> dict:
    """
    Crawl hymns for a given category.

    Args:
        category: Hymn category code (ch, ts, h, ns, lb, nt)
        start: Starting hymn number (defaults to category default)
        end: Ending hymn number inclusive (defaults to category default)
        output_dir: Directory to save hymns
        batch_size: Number of hymns per save batch
        delay: Delay between requests in seconds
        fetch_related: Whether to fetch related hymns (defaults based on category)

    Returns:
        Dictionary with statistics: {total, fetched, skipped}
    """
    if category not in CATEGORY_RANGES:
        raise ValueError(f"Unsupported category: {category}. "
                         f"Supported: {list(CATEGORY_RANGES.keys())}")

    # Use defaults if not specified
    default_start, default_end = CATEGORY_RANGES[category]
    start = start if start is not None else default_start
    end = end if end is not None else default_end

    # Default fetch_related based on category (Chinese hymns fetch related)
    if fetch_related is None:
        fetch_related = category in ('ch', 'ts')

    language = CATEGORY_LANGUAGES[category]

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Initialize crawler
    crawler = HymnalCrawler()

    print(f"\n{'=' * 60}")
    print(f"Crawling {category.upper()} hymns: {start} to {end}")
    print(f"Language: {language}")
    print(f"Fetch related: {fetch_related}")
    print(f"Output directory: {output_dir}")
    print(f"{'=' * 60}\n")

    all_hymns = []
    batch_hymns = []
    total_fetched = 0
    total_skipped = 0

    for num in range(start, end + 1):
        url = f"{crawler.base_url}/{language}/hymn/{category}/{num}"
        print(f"  [{num}/{end}] Fetching {category}_{num}...", end=" ", flush=True)

        hymn_data = crawler.fetch_hymn(
            url,
            fetch_related=fetch_related,
            output_dir=output_dir
        )

        if hymn_data:
            all_hymns.append(hymn_data)
            batch_hymns.append(hymn_data)
            total_fetched += 1
            # Print truncated title
            title = hymn_data.get('title', 'Unknown')
            if len(title) > 40:
                title = title[:37] + "..."
            print(f"✓ {title}")
        else:
            total_skipped += 1
            print("✗ Skipped")

        # Save batch when we reach batch_size
        if len(batch_hymns) >= batch_size:
            print(f"\n  Saving batch ({len(batch_hymns)} hymns)...")
            crawler.save_hymns(batch_hymns, output_dir)
            print(f"  ✓ Batch saved (total: {total_fetched})\n")
            batch_hymns = []

        # Rate limiting
        time.sleep(delay)

    # Save any remaining hymns in the last batch
    if batch_hymns:
        print(f"\n  Saving final batch ({len(batch_hymns)} hymns)...")
        crawler.save_hymns(batch_hymns, output_dir)
        print(f"  ✓ Final batch saved")

    # Summary
    print(f"\n{'=' * 60}")
    print(f"SUMMARY: {category.upper()}")
    print(f"{'=' * 60}")
    print(f"Total processed: {end - start + 1}")
    print(f"Successfully fetched: {total_fetched}")
    print(f"Skipped: {total_skipped}")
    print(f"{'=' * 60}\n")

    return {
        "category": category,
        "total": end - start + 1,
        "fetched": total_fetched,
        "skipped": total_skipped,
    }


def crawl_multiple_categories(
    categories: list,
    output_dir: str = "hymns",
    **kwargs
) -> list:
    """
    Crawl multiple categories in sequence.

    Args:
        categories: List of category codes to crawl
        output_dir: Directory to save hymns
        **kwargs: Additional arguments passed to crawl_category

    Returns:
        List of statistics dictionaries for each category
    """
    results = []
    for category in categories:
        result = crawl_category(category, output_dir=output_dir, **kwargs)
        results.append(result)
    return results


def main():
    """CLI entry point for crawling a single category."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Crawl hymns from hymnal.net"
    )
    parser.add_argument(
        "category",
        choices=list(CATEGORY_RANGES.keys()),
        help="Hymn category to crawl"
    )
    parser.add_argument(
        "--start",
        type=int,
        default=None,
        help="Starting hymn number"
    )
    parser.add_argument(
        "--end",
        type=int,
        default=None,
        help="Ending hymn number"
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="hymns",
        help="Output directory (default: hymns)"
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
    parser.add_argument(
        "--fetch-related",
        action="store_true",
        default=None,
        help="Fetch related hymns"
    )
    parser.add_argument(
        "--no-fetch-related",
        action="store_true",
        help="Do not fetch related hymns"
    )

    args = parser.parse_args()

    # Handle fetch_related flag
    fetch_related = None
    if args.fetch_related:
        fetch_related = True
    elif args.no_fetch_related:
        fetch_related = False

    crawl_category(
        category=args.category,
        start=args.start,
        end=args.end,
        output_dir=args.output_dir,
        batch_size=args.batch_size,
        delay=args.delay,
        fetch_related=fetch_related,
    )


if __name__ == "__main__":
    main()
