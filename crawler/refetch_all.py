#!/usr/bin/env python3
"""
Refetch all existing hymns with updated structure (no root-level lines).
"""

import os
import re
import sys
import time
import logging
from hymnal_crawler import HymnalCrawler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

def main():
    # Get all JSON files
    json_files = [f for f in os.listdir('hymns') if f.endswith('.json')]
    print(f'Refetching {len(json_files)} hymns with updated structure...\n', flush=True)

    # Parse filenames to get category and number
    hymns_to_fetch = []
    pattern = re.compile(r'^([a-z]+)_(\d+)\.json$')

    for filename in sorted(json_files):
        match = pattern.match(filename)
        if match:
            category = match.group(1)
            number = match.group(2)
            hymns_to_fetch.append((category, int(number)))

    print(f'Parsed {len(hymns_to_fetch)} hymn URLs\n', flush=True)

    # Refetch all hymns
    crawler = HymnalCrawler()
    refetched_hymns = []
    failed = []
    batch_size = 10

    for i, (category, number) in enumerate(hymns_to_fetch, 1):
        url = f'https://www.hymnal.net/cn/hymn/{category}/{number}'

        # Show progress
        if i == 1 or i % 10 == 0 or i == len(hymns_to_fetch):
            print(f'Progress: {i}/{len(hymns_to_fetch)} ({i*100//len(hymns_to_fetch)}%) - Fetching {category}/{number}', flush=True)

        hymn = crawler.fetch_hymn(url)
        if hymn:
            refetched_hymns.append(hymn)

            # Save in batches to avoid losing data
            if len(refetched_hymns) >= batch_size:
                crawler.save_hymns(refetched_hymns, output_dir='hymns')
                refetched_hymns = []
        else:
            failed.append(url)
            print(f'  Failed: {url}', flush=True)

        # Be respectful to the server
        time.sleep(1)

    # Save remaining hymns
    if refetched_hymns:
        crawler.save_hymns(refetched_hymns, output_dir='hymns')

    print(f'\n{"="*60}', flush=True)
    print(f'Completed!', flush=True)
    print(f'Successfully refetched: {len(hymns_to_fetch) - len(failed)} hymns', flush=True)
    print(f'Failed: {len(failed)} hymns', flush=True)

    if failed:
        print(f'\nFailed URLs:', flush=True)
        for url in failed:
            print(f'  {url}', flush=True)

if __name__ == '__main__':
    main()
