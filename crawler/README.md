# Hymnal.net Crawler

A Python web crawler for downloading hymns and chords from hymnal.net.

## Installation

1. Create and activate a virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:

```bash
pip install -r requirements.txt
```

## Quick Start

```bash
# Activate the virtual environment
source venv/bin/activate

# Run the basic example
python hymnal_crawler.py

# Or run the comprehensive examples
python example_usage.py
```

## Usage

### Basic Usage

Fetch a single hymn:

```python
from hymnal_crawler import HymnalCrawler

crawler = HymnalCrawler()
hymn = crawler.fetch_hymn("https://www.hymnal.net/cn/hymn/ts/846")
crawler.save_hymns([hymn], output_dir="hymns")
```

### Crawl Multiple Hymns

Crawl a range of hymns from a category:

```python
from hymnal_crawler import HymnalCrawler

crawler = HymnalCrawler()

# Crawl hymns 846-850 from the 'ts' category
hymns = crawler.crawl_hymn_range('ts', start=846, end=850)
crawler.save_hymns(hymns, output_dir="hymns")
```

### Upload to Google Cloud Firestore

Upload your crawled hymns to Firestore:

```python
from hymnal_crawler import FirestoreUploader

# Initialize uploader with your Firebase service account key
uploader = FirestoreUploader(
    service_account_key_path="path/to/firebase-service-account.json",
    collection_name="hymns"
)

# Upload all JSON files from a directory
results = uploader.upload_hymns_from_directory("hymns")
print(f"Uploaded {len(results['success'])} hymns")

# Or use batch upload for better performance
import json
import glob

hymn_data_list = []
for json_file in glob.glob("hymns/*.json"):
    with open(json_file, 'r', encoding='utf-8') as f:
        hymn_data_list.append(json.load(f))

results = uploader.batch_upload_hymns(hymn_data_list)
```

**Setup Requirements:**
1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Firestore Database
3. Generate a service account key (Project Settings > Service Accounts)
4. Save the key as `firebase-service-account.json` (or any name)
5. Run `python firestore_example.py` for a complete example

See `CLAUDE.md` for detailed Firestore setup instructions.

### Run the Example

```bash
python hymnal_crawler.py
```

## Output

The crawler saves hymns in two formats:

1. **JSON file** (`hymns/hymns.json`) - Contains all hymn data in structured format
2. **Individual text files** (`hymns/hymn_1.txt`, etc.) - One file per hymn with title, metadata, and chords/lyrics

## Process
1. Fetch all hymns
2. Fix Chinese characters
3. Overwrite from the manual edits.

## Hymn Categories

Common category codes:
- `ts` - Traditional hymns (Chinese)
- `h` - English hymns
- `ns` - New songs
- `c` - Children's songs

## Customization

If the page structure differs from expected, you can modify the `parse_hymn_page` method to adjust the CSS selectors:

```python
# Modify this line to match the actual class name:
chord_divs = soup.find_all('div', class_='chord-text')
```

## Notes

- The crawler includes a 1-second delay between requests to be respectful to the server
- Please respect the website's terms of service and copyright
- Hymns may be subject to copyright restrictions

## Legal Notice

This tool is for personal use and educational purposes. Please respect copyright laws and the website's terms of service. Many hymns, especially older ones, are in the public domain, but you should verify the copyright status before distributing any content.
