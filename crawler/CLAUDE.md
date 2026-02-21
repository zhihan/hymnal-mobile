# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Python web crawler for downloading hymns and chords from hymnal.net. The crawler fetches hymn pages, parses HTML content using BeautifulSoup, and saves the data as JSON files.

**Part of**: This crawler is part of the `hymnal_mobile` monorepo. The JSON files it generates are used by the Flutter mobile app. See the parent `CLAUDE.md` for the full project overview.

**Data Flow**:
```
hymnal.net → crawler → hymns/*.json → (copy to) assets/hymns/ → Flutter app
```

## Development Setup

```bash
# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## Running the Code

```bash
# Activate virtual environment (required before running)
source venv/bin/activate

# Run basic single-hymn example
python main.py

# Run comprehensive examples
python example_usage.py

# Run tests
pytest tests/
```

## Project Structure

```
crawler/
├── hymnal_crawler/              # Main library package
│   ├── __init__.py             # Package exports (HymnalCrawler)
│   └── crawler.py              # HymnalCrawler class (~800 lines)
├── tests/                       # Unit tests
│   ├── __init__.py
│   ├── test_crawler.py         # Tests for HymnalCrawler
│   └── test_manual_edits.py    # Tests for manual edit protection
├── hymns/                       # Generated hymn JSON files (~4,000+ files)
├── hymns_manual/                # Manually edited hymns (protected from overwrite)
├── main.py                      # Basic single-hymn example
├── example_usage.py             # Comprehensive usage examples
├── crawl_all.py                # Master script: crawl all, convert, apply manual edits
├── crawl_hymns.py              # Consolidated crawling module for any category
├── refetch_all.py              # Refetch all existing hymns
├── find_missing_chords.py      # Identify hymns without chords
├── convert_to_simplified.py    # Convert single hymn to simplified Chinese
├── batch_convert_chinese_hymns.py  # Batch convert Chinese hymns
├── requirements.txt             # Python dependencies
└── CLAUDE.md                    # This file
```

## Architecture

### Core Components

**HymnalCrawler** (`hymnal_crawler/crawler.py`) - The main crawler class with three primary responsibilities:

1. **Fetching** - Uses requests.Session with custom User-Agent headers to retrieve hymn pages
2. **Parsing** - Extracts hymn data from HTML using BeautifulSoup:
   - Title from `<h2>` or `<h1>` tags
   - Lines from `div.line` containers, where each line contains:
     - Multiple `div.chord-text` elements with `<span class="chord">` for chord names
     - Plain text nodes between chord-text elements
     - Each segment stored as `{chord, text}` pairs
   - Metadata from `div.details` or `div.metadata` sections
   - Category from `<a>` elements with href matching `/<lang>/search/all/category/`, where lang is 'en' or 'cn' (excludes links in `div.list-group`)
   - Time from `<a>` elements with href matching `/<lang>/search/all/time/`, where lang is 'en' or 'cn' (excludes links in `div.list-group`)
   - Hymn code from `<a>` elements with href matching `/<lang>/search/all/hymncode/`, where lang is 'en' or 'cn' (excludes links in `div.list-group`)
   - Guitar leadsheet URL from `div.leadsheet.guitar` containing an `<img>` tag with src attribute
   - Related hymns from `<a>` elements within `div.hymn-nums` container, matching href pattern `/<lang>/hymn/<category>/number`, where lang is 'en' or 'cn' and category is in `SUPPORTED_CATEGORIES` (excludes links in `div.list-group` and unsupported categories)
   - Fallback parsing:
     - `div.chord-container` for simple lyrics without line structure
     - `div.hymn-content`, `div#hymn-content`, or `div.lyrics` for basic content
3. **Saving** - Outputs data as JSON files:
   - `<category>_<hymn_number>.json` - Complete structured data with lines array

### Key Methods

- `fetch_hymn(url)` - Fetches and parses a single hymn URL. Applies validation based on language and category.
- `parse_hymn_page(html, url)` - Extracts structured data from HTML. Returns None if validation fails.
- `crawl_hymn_range(category, start, end)` - Crawls multiple hymns with 1-second delay between requests. Validates that the category is in `SUPPORTED_CATEGORIES` before crawling. Language is automatically determined from the category using `get_language_from_category()`.
- `save_hymns(hymns, output_dir)` - Saves hymns to JSON and text files
- `get_language_from_category(category)` - Static method that determines language code ('en' or 'cn') from category code. Returns 'en' for 'h', 'ns', 'lb', 'nt'; returns 'cn' for 'ch', 'ts'.
- `contains_chinese(text)` - Static method that checks if text contains Chinese characters
- `contains_english_hymn_tag(hymn_nums_container, expected_number, category)` - Static method that validates English hymn tags based on category

### Class Constants

- `SUPPORTED_CATEGORIES` - Dictionary mapping category codes to descriptions. Only these categories are allowed in `crawl_hymn_range()`:
  - `'h'`: English Hymns
  - `'ns'`: New Songs
  - `'ch'`: Chinese Classical Hymns (大本)
  - `'ts'`: Chinese New Hymns (補充本)
  - `'lb'`: New Songs (lb variant, English)
  - `'nt'`: New Tune (English)

### Validation Behavior

The crawler applies different validation rules based on language and category:

- **English 'h' hymns** (`language='en'`, `category='h'`):
  - Validates that `div.hymn-nums` container contains the expected tag in format `E{number}` (e.g., E1234)
  - Pages without the matching tag are skipped and return None

- **Chinese hymns** (`language='cn'`):
  - Validates that title or content contains Chinese characters
  - Pages without Chinese characters are skipped and return None

- **Other combinations**: No special validation applied

### URL Pattern

Hymns follow this URL structure: `https://www.hymnal.net/{language}/hymn/{category}/{number}`

Where launguage can be:
- `en`: English
- `cn`: Chinese (simplified)

Supported categories (defined in `HymnalCrawler.SUPPORTED_CATEGORIES`):
- `ts` - Chinese New Hymns (補充本)
- `ch` - Chinese Classical Hymns (大本)
- `h` - English Hymns
- `ns` - New Songs
- `lb` - New Songs (lb variant, English)
- `nt` - New Tune (English)

Other categories exist on the website but are not currently supported:
- `c` - Children's songs

### Output Structure

Hymn data dictionary contains:
- `url` - Source URL
- `title` - Hymn title
- `verses` - Array of verse objects, where each verse contains:
  - `lines` - Array of line objects, where each line contains:
    - `segments` - Array of segment objects with `{chord: string, text: string}` structure
    - Example line: `{"segments": [{"chord": "G", "text": "當 我"}, {"chord": "", "text": "們 開 口"}]}`
- `metadata` - Dictionary of extracted metadata including:
  - Standard key-value pairs from `div.details` or `div.metadata`
  - `category` - Extracted from category links
  - `time` - Extracted from time signature links
  - `hymn_code` - Extracted from hymn code links
  - `guitar_leadsheet_url` - URL to guitar leadsheet SVG image (from `div.leadsheet.guitar img`)
  - `related` - Array of related hymn objects (only supported categories from `div.hymn-nums`)
- `raw_sections` - List of raw text content (for backward compatibility)

## HTML Structure

The hymnal.net pages use the following structure for lyrics with chords:

```html
<div class="line">
  <div class="chord-text"><span class="chord">G</span>當 我</div>
  們 開 口
  <div class="chord-text"><span class="chord">D</span>讚</div>
  <div class="chord-text"><span class="chord">D7</span>美，</div>
</div>
```

This represents a line where:
- Chord "G" goes with text "當 我"
- Plain text "們 開 口" (no chord)
- Chord "D" goes with text "讚"
- Chord "D7" goes with text "美，"

## Modifying Parsing Logic

If the website's HTML structure changes, update the CSS selectors in `hymnal_crawler/crawler.py` in the `parse_hymn_page()` method:

### Primary Parsing (Lines with Chords)
- `div.verse` - Container for each verse of lyrics.
- `div.line` - Container for each line of lyrics
- Within each `div.line`:
  - `div.chord-text` - Contains chord and associated text
  - `span.chord` - Chord name within chord-text div
  - Text nodes - Plain text between chord-text elements

### Fallback Parsing (No Line Containers)
- `div.chord-container` - Simple lyrics without detailed chord structure
- `div.hymn-content`, `div#hymn-content`, or `div.lyrics` - Basic content area

### Metadata Extraction
- `div.details` or `div.metadata` - Key-value pairs
- `<a>` elements with href patterns (excluding links in `div.list-group`):
  - `/<lang>/search/all/category/` for category
  - `/<lang>/search/all/time/` for time signature
  - `/<lang>/search/all/hymncode/` for hymn code
- `div.hymn-nums` container for related hymns:
  - `<a>` elements with href pattern `/<lang>/hymn/<category>/<number>`
  - Only includes categories in `SUPPORTED_CATEGORIES`
  - Excludes links in `div.list-group`

## Rate Limiting

The crawler includes a 1-second delay (`time.sleep(1)`) in `crawl_hymn_range()` to be respectful to the server. Do not reduce this delay.

## Manual Hymn Editing

The crawler supports manual editing of hymns through a dedicated `hymns_manual/` directory:

### Directory Structure

```
crawler/
├── hymns/              # Crawler-saved hymns (auto-generated)
└── hymns_manual/       # Manual edits (NEVER overwritten)
    ├── ts_5.json
    └── ...
```

### How Manual Edits Work

1. **Protection from Overwriting**: Any hymn JSON file in `hymns_manual/` will NEVER be overwritten by the crawler

### Creating Manual Edits

To manually edit a hymn:

```bash
# 1. Copy the hymn from hymns/ to hymns_manual/
mkdir -p hymns_manual
cp hymns/ts_5.json hymns_manual/ts_5.json

# 2. Edit the file manually
nano hymns_manual/ts_5.json

# 3. The crawler will now skip this hymn when saving
```

### Using Manual Edits in Code

```python
from hymnal_crawler import HymnalCrawler

# Initialize crawler (manual_dir is configurable)
crawler = HymnalCrawler(manual_dir="hymns_manual")

# Batch operations automatically skip manual edits
hymns = crawler.crawl_hymn_range('ts', 1, 100)
crawler.save_hymns(hymns, output_dir="hymns")  # Skips ts_5 if in hymns_manual/
```

### Configuration

The manual directory can be customized:

```python
# Use a custom manual directory
crawler = HymnalCrawler(manual_dir="my_custom_edits")
```

## Crawling Scripts

### crawl_all.py (Master Script)
The main entry point for crawling all hymns. Executes a 4-phase pipeline:
1. Crawl Chinese hymns (ch, ts)
2. Crawl English hymns (lb, nt, h, ns)
3. Convert Chinese hymns to simplified Chinese
4. Copy manual edits from `hymns_manual/` to `hymns/`

```bash
# Full pipeline
python crawl_all.py

# Preview what would be done
python crawl_all.py --dry-run

# Skip specific phases
python crawl_all.py --skip-chinese          # Skip Chinese hymns
python crawl_all.py --skip-english          # Skip English hymns
python crawl_all.py --skip-convert          # Skip Chinese conversion
python crawl_all.py --skip-manual           # Skip manual edits

# Customize output
python crawl_all.py --output-dir hymns --manual-dir hymns_manual

# Adjust rate limiting
python crawl_all.py --delay 1.0 --batch-size 25
```

### crawl_hymns.py (Single Category)
Consolidated module for crawling a single category. Replaces the old `crawl_*.py` and `fetch_*.py` scripts.

```bash
# Crawl specific category with defaults
python crawl_hymns.py ch          # Chinese Classical (1-800)
python crawl_hymns.py ts          # Chinese New (1-1000)
python crawl_hymns.py h           # English Hymns (1-1400)
python crawl_hymns.py ns          # New Songs (1-1200)
python crawl_hymns.py lb          # New Songs lb (1-100)
python crawl_hymns.py nt          # New Tune (1-1400)

# Custom range
python crawl_hymns.py ch --start 1 --end 100

# Options
python crawl_hymns.py ts --fetch-related     # Fetch related hymns
python crawl_hymns.py h --no-fetch-related   # Don't fetch related
python crawl_hymns.py ch --delay 1.0         # 1 second between requests
```

## Utility Scripts

### find_missing_chords.py
Scans the `hymns/` directory and identifies hymns that have no chord data. Copies these files to `hymns_manual/` for manual editing.

```bash
python find_missing_chords.py
```

### convert_to_simplified.py
Converts a single hymn file from traditional to simplified Chinese.

```bash
python convert_to_simplified.py hymns/ch_100.json
```

### batch_convert_chinese_hymns.py
Batch converts all ch and ts hymns to simplified Chinese. Supports `--dry-run` flag.

```bash
python batch_convert_chinese_hymns.py          # Convert all
python batch_convert_chinese_hymns.py --dry-run # Preview changes
```

### refetch_all.py
Refetches all existing hymns with updated parsing logic. Useful after making changes to the crawler.

```bash
python refetch_all.py
```

## Deploying to Flutter App

After crawling hymns, copy the JSON files to the Flutter app's assets:

```bash
# From the repository root
cp crawler/hymns/*.json assets/hymns/

# Or merge manual edits (manual edits take priority)
cp crawler/hymns/*.json assets/hymns/
cp crawler/hymns_manual/*.json assets/hymns/
```

Then rebuild the Flutter app to include the updated hymn data.
