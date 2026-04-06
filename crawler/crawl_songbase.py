#!/usr/bin/env python3
"""
CLI entry point for crawling songbase.life hymns.

Fetches hymns via the songbase.life API and saves them in our JSON format.
"""

import argparse
import logging

from songbase_crawler import SongbaseCrawler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)


def main():
    parser = argparse.ArgumentParser(
        description="Crawl songbase.life hymns and save as JSON"
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="hymns_songbase",
        help="Output directory for hymns (default: hymns_songbase)"
    )
    parser.add_argument(
        "--book",
        type=str,
        default=None,
        choices=list(SongbaseCrawler.BOOK_MAPPING.keys()),
        help="Crawl a specific book only (default: all mapped books)"
    )
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Force re-fetch from API instead of using cached data"
    )
    parser.add_argument(
        "--cache-file",
        type=str,
        default="songbase_raw.json",
        help="Path to cache file for API data (default: songbase_raw.json)"
    )

    args = parser.parse_args()

    crawler = SongbaseCrawler(cache_file=args.cache_file)
    use_cache = not args.no_cache

    if args.book:
        print(f"\nCrawling songbase.life book: {args.book}")
        result = crawler.crawl_book(args.book, output_dir=args.output_dir, use_cache=use_cache)
        results = [result]
    else:
        print(f"\nCrawling all songbase.life books")
        results = crawler.crawl_all_books(output_dir=args.output_dir, use_cache=use_cache)

    # Summary
    print(f"\n{'=' * 60}")
    print("SONGBASE CRAWL SUMMARY")
    print(f"{'=' * 60}")
    for r in results:
        print(f"  {r['book_slug']} ({r['book_id']}): {r['converted']}/{r['total']} converted, {r['errors']} errors")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
