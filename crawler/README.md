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

# Run the basic single-hymn example
python main.py

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

### Run the Example

```bash
python main.py
```

## Output

The crawler saves one JSON file per hymn, named `<category>_<number>.json`
(e.g. `h_1.json`, `ts_846.json`, `sb_12345.json`).

## Process

1. Fetch hymn pages from hymnal.net (and songbase.life via API)
2. Parse lyrics, chords, and metadata into structured JSON
3. Save to `hymns/` (files in `hymns_manual/` are never overwritten)

## Hymn Categories

Supported category codes (see `HymnalCrawler.SUPPORTED_CATEGORIES`):
- `ch` - Chinese Classical Hymns (大本)
- `ts` - Chinese New Hymns (補充本)
- `h` - English Hymns
- `ns` - New Songs
- `lb` - New Songs (lb variant, English)
- `nt` - New Tune (English)
- `sb` - SongBase English songs (from songbase.life)

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
