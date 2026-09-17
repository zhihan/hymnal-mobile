# Hymnal.net Crawler

A Python web crawler for downloading hymns and chords from hymnal.net (plus
English songs from songbase.life). The JSON files it generates are the data
source for the Flutter app in this repo.

## Setup

Requires Python 3.14.

```bash
cd crawler
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## The Pipeline

The normal workflow is the full build from the repo root — crawl, copy the
JSON into the app's asset directory, and regenerate the hymn index:

```bash
./build_hymns.sh                # Full pipeline
./build_hymns.sh --skip-midi    # Skip the MIDI download / melody extraction step
./build_hymns.sh --skip-crawl   # Reuse crawler/hymns/, just copy + rebuild
./build_hymns.sh --songbase-only  # Fast path: songbase API only
```

Under the hood, `./build_hymns.sh` runs `crawler/crawl_all.py`, a 7-phase
pipeline:

1. Crawl Chinese hymns from hymnal.net (`ch`, `ts`)
2. Crawl English hymns (`h`, `ns`, `lb`, `nt`)
3. Crawl English songs from songbase.life (API)
4. Deduplicate and merge songbase results into `hymns/`
5. Convert Chinese hymns to simplified Chinese
6. Apply manual edits from `hymns_manual/`
7. Download MIDI tunes and embed melody notes (on by default; `--skip-midi` to opt out)

Then it copies `crawler/hymns/*.json` to the repo-root `hymns/` directory and
regenerates `assets/available_hymns.json` via `dart run tool/build_database.dart`.

Useful `crawl_all.py` flags: `--dry-run`, `--skip-chinese`, `--skip-english`,
`--skip-songbase`, `--skip-convert`, `--skip-manual`, `--skip-midi`, `--delay`,
`--batch-size`.
See `python crawl_all.py --help`.

## Melody Extraction (Phase 7)

`extract_midi_notes.py` downloads each hymn's `metadata.midi_tune_url`,
selects the most melody-like track, and writes compact pitch/timing data to
`metadata.melody`. The app renders guitar tablature on-device from these
notes. It runs as Phase 7 of `crawl_all.py` by default; pass `--skip-midi`
(or `./build_hymns.sh --skip-midi`) to skip it.

Note: a full crawl rewrites every hymn file from scratch, wiping any
previously stored melody — so a full build re-downloads all ~4,033 MIDI
tunes. Running the extractor standalone
against an existing corpus is incremental instead: hymns whose stored
melody is already current are skipped before any HTTP request.

```bash
# Refresh melodies without re-crawling
python extract_midi_notes.py --hymns-dir hymns

# One hymn, or force a full re-extract
python extract_midi_notes.py --file hymns/h_350.json
python extract_midi_notes.py --hymns-dir hymns --force
```

## Single-Category Crawls

`crawl_hymns.py` crawls one category at a time (defaults cover the full range):

```bash
python crawl_hymns.py ch          # Chinese Classical (1-800)
python crawl_hymns.py ts          # Chinese New Hymns (1-1000)
python crawl_hymns.py h           # English Hymns (1-1400)
python crawl_hymns.py ns          # New Songs (1-1200)
python crawl_hymns.py lb          # New Songs lb (1-100)
python crawl_hymns.py nt          # New Tune (1-1400)

python crawl_hymns.py ch --start 1 --end 100   # Custom range
python crawl_hymns.py ts --fetch-related       # Also fetch related hymns
```

## Library Usage

```python
from hymnal_crawler import HymnalCrawler

crawler = HymnalCrawler()

# Fetch and parse a single hymn page
hymn = crawler.fetch_hymn("https://www.hymnal.net/en/hymn/h/350")

# Crawl a range, then save
hymns = crawler.crawl_hymn_range("h", start=1, end=50)
crawler.save_hymns(hymns, output_dir="hymns")
```

## Output

One JSON file per hymn, named `<category>_<number>.json` (e.g. `h_350.json`).
Each file contains:

- `url`, `title`
- `verses` — verses → lines → segments of `{chord, text}` pairs
- `metadata` — key/value details plus extracted fields:
  `category`, `time`, `hymn_code`, `guitar_leadsheet_url`, `related`,
  `tune_links` (Original/New/Alternate Tune NT↔H links), `language_indices`,
  `midi_tune_url`, and `melody` (after Phase 7)

## Manual Edits

Files placed in `hymns_manual/` are never overwritten by the crawler; Phase 6
copies them over the crawled output. To hand-fix a hymn:

```bash
mkdir -p hymns_manual
cp hymns/ts_5.json hymns_manual/ts_5.json
# edit hymns_manual/ts_5.json, then re-run the pipeline
```

## Utility Scripts

- `batch_convert_chinese_hymns.py` — convert `ch`/`ts` hymns to simplified Chinese (`--dry-run` supported)
- `dedup_hymns.py` — deduplicate/merge songbase results into `hymns/`

## Tests

```bash
pytest tests/
```

## Notes

- The crawler waits 1 second between page requests; MIDI downloads default to
  a 0.5s delay (`--delay`). Both identify with a browser User-Agent. Be
  respectful to the servers and their terms of service.
- Hymns may be subject to copyright restrictions; verify before distributing.

## Legal Notice

This tool is for personal use and educational purposes. Please respect
copyright laws and the website's terms of service.
