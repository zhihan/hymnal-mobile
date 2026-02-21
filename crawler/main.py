#!/usr/bin/env python3
"""
Main entry point for the Hymnal.net crawler.
"""

import logging
from hymnal_crawler import HymnalCrawler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)


def main():
    """Main function to demonstrate basic usage."""
    crawler = HymnalCrawler()

    # Example 1: Fetch a single hymn
    print("Fetching sample hymn...")
    hymn = crawler.fetch_hymn("https://www.hymnal.net/cn/hymn/ts/846")

    if hymn:
        print(f"\nTitle: {hymn['title']}")
        print(f"Verses: {len(hymn.get('verses', []))}")

        # Show preview of first verse
        verses = hymn.get('verses', [])
        if verses:
            print(f"\nVerse 1 preview (first 3 lines):")
            first_verse_lines = verses[0].get('lines', [])
            for i, line in enumerate(first_verse_lines[:3]):
                print(f"\n  Line {i+1}:")
                segments = line.get('segments', []) if isinstance(line, dict) else line
                for segment in segments:
                    if segment['chord']:
                        print(f"    [{segment['chord']}] {segment['text']}")
                    else:
                        print(f"    {segment['text']}")
            if len(first_verse_lines) > 3:
                print("\n  ...")

        # Save the single hymn
        crawler.save_hymns([hymn], output_dir="hymns")

    # Example 2: Crawl a range of hymns (commented out by default)
    # print("\nCrawling hymns 846-850...")
    # hymns = crawler.crawl_hymn_range('ts', 846, 850)
    # crawler.save_hymns(hymns, output_dir="hymns")


if __name__ == "__main__":
    main()
