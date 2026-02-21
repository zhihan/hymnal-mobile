#!/usr/bin/env python3
"""
Example usage of the Hymnal.net crawler
"""

import logging
from hymnal_crawler import HymnalCrawler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)


def example_single_hymn():
    """Example: Fetch a single hymn"""
    print("=" * 60)
    print("Example 1: Fetching a single hymn")
    print("=" * 60)

    crawler = HymnalCrawler()
    hymn = crawler.fetch_hymn("https://www.hymnal.net/cn/hymn/ts/846")

    if hymn:
        print(f"Title: {hymn['title']}")
        print(f"URL: {hymn['url']}")
        print(f"\nFirst 5 blocks of content:")
        for i, block in enumerate(hymn['chords_and_lyrics'][:5], 1):
            print(f"  Block {i}:")
            print(f"    Chord: {block['chord']}")
            print(f"    Lyrics: {', '.join(block['lyrics']) if block['lyrics'] else '(none)'}")
        print("...")

        crawler.save_hymns([hymn], output_dir="hymns/single")
        print("\nSaved to hymns/single/")


def example_hymn_range():
    """Example: Crawl a range of hymns"""
    print("\n" + "=" * 60)
    print("Example 2: Crawling a range of hymns")
    print("=" * 60)

    crawler = HymnalCrawler()

    # Crawl hymns 846-848 from 'ts' category
    hymns = crawler.crawl_hymn_range('ts', start=846, end=848)

    print(f"\nFetched {len(hymns)} hymns:")
    for hymn in hymns:
        print(f"  - {hymn['title']} ({hymn['url']})")

    crawler.save_hymns(hymns, output_dir="hymns/range")
    print("\nSaved to hymns/range/")


def example_multiple_categories():
    """Example: Fetch hymns from different categories"""
    print("\n" + "=" * 60)
    print("Example 3: Fetching from different categories")
    print("=" * 60)

    crawler = HymnalCrawler()
    all_hymns = []

    categories = [
        ('ts', 846),  # Traditional songs
        ('ts', 847),
    ]

    for category, num in categories:
        url = f"https://www.hymnal.net/cn/hymn/{category}/{num}"
        hymn = crawler.fetch_hymn(url)
        if hymn:
            all_hymns.append(hymn)
            print(f"Fetched: {hymn['title']}")

    crawler.save_hymns(all_hymns, output_dir="hymns/mixed")
    print(f"\nSaved {len(all_hymns)} hymns to hymns/mixed/")


def example_custom_parsing():
    """Example: Access raw sections for custom processing"""
    print("\n" + "=" * 60)
    print("Example 4: Custom processing of hymn sections")
    print("=" * 60)

    crawler = HymnalCrawler()
    hymn = crawler.fetch_hymn("https://www.hymnal.net/cn/hymn/ts/846")

    if hymn:
        print(f"Title: {hymn['title']}")
        print(f"\nNumber of blocks: {len(hymn['chords_and_lyrics'])}")
        print("\nFirst 5 blocks:")
        for i, block in enumerate(hymn['chords_and_lyrics'][:5], 1):
            lyrics = ' '.join(block['lyrics']) if block['lyrics'] else "(none)"
            print(f"  {i}. Chord: {block['chord']:8s} Lyrics: {lyrics}")


if __name__ == "__main__":
    # Run all examples
    example_single_hymn()

    # Uncomment to run other examples:
    # example_hymn_range()
    # example_multiple_categories()
    # example_custom_parsing()

    print("\n" + "=" * 60)
    print("Done! Check the 'hymns' directory for output files.")
    print("=" * 60)
