# Hymnal Mobile

Flutter app and crawler for browsing hymns with inline chords, search, song lists, MIDI playback, and guitar leadsheets.

The repository has two parts:

- `./`: Flutter mobile app
- `./crawler`: Python crawler that fetches hymn data from hymnal.net and writes JSON files consumed by the app

## Repository Layout

```text
hymnal-mobile/
├── lib/                  Flutter app source
├── hymns/                Generated hymn JSON assets for the app (not tracked)
├── assets/
│   ├── available_hymns.json
│   ├── icon/
│   └── soundfont.sf2     Required for MIDI playback (not tracked)
├── crawler/              Hymn crawler and data pipeline
└── test/                 Dart tests
```

## What The App Does

- Loads hymn content from bundled local JSON files
- Builds an Isar search index on first launch from those JSON assets
- Supports direct hymn lookup by book and number
- Supports full-text search across titles and lyrics
- Organizes hymns into song lists, including a default `Favorites` list
- Imports and exports song lists through shareable deep links
- Displays chords inline with lyrics and supports chord transposition
- Plays MIDI files when a hymn provides a MIDI URL
- Opens guitar leadsheets when a hymn provides a leadsheet URL

## Data Files

The app expects two generated asset inputs:

- `hymns/*.json`
- `assets/available_hymns.json`

`hymns/` is intentionally gitignored because it is large generated content. In this checkout, the folder may not exist until you generate or copy the hymn data.

Each hymn file is named `{bookId}_{number}.json`, for example:

- `ch_100.json`
- `ts_1.json`
- `h_500.json`
- `ns_50.json`

Supported book IDs in the app and crawler:

- `ch`: Chinese Classical Hymns
- `ts`: Chinese Supplement
- `h`: English Hymns
- `ns`: New Songs
- `lb`: New Songs (LB)
- `nt`: New Tune

## Flutter App Setup

### Prerequisites

- Flutter SDK
- Xcode for iOS development
- Android SDK and Android Studio for Android development

### Required Local Assets

#### 1. Hymn JSON files

Generate them with the crawler or copy them into the repo root as `hymns/`.

The Flutter app loads hymn files from `hymns/`, not from `assets/hymns/`.

#### 2. MIDI soundfont

MIDI playback requires `assets/soundfont.sf2`, which is not tracked because of file size.

Examples:

```bash
# macOS
brew install fluid-soundfont
cp /usr/share/sounds/sf2/FluidR3_GM.sf2 assets/soundfont.sf2

# Debian/Ubuntu
sudo apt install fluid-soundfont-gm
cp /usr/share/sounds/sf2/FluidR3_GM.sf2 assets/soundfont.sf2
```

Any General MIDI `.sf2` file should work.

### Install And Run

```bash
flutter pub get
flutter run
```

Useful commands:

```bash
flutter devices
flutter run -d <device_id>
flutter test
flutter analyze
flutter format lib test
```

## Crawler Setup

The crawler lives in `./crawler`.

```bash
cd crawler
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Run tests:

```bash
pytest tests/
```

Fetch all supported hymn sets:

```bash
python crawl_all.py
```

Preview without making changes:

```bash
python crawl_all.py --dry-run
```

Fetch a single category:

```bash
python crawl_hymns.py ch
python crawl_hymns.py ts
python crawl_hymns.py h
python crawl_hymns.py ns
python crawl_hymns.py lb
python crawl_hymns.py nt
```

Other crawler utilities:

```bash
python refetch_all.py
python find_missing_chords.py
python batch_convert_chinese_hymns.py
```

## Data Pipeline

```text
hymnal.net
  -> crawler/hymnal_crawler/crawler.py
  -> crawler/hymns/*.json
  -> copy or sync into ./hymns/*.json
  -> Flutter app
  -> Isar search index on first launch
```

The crawler also supports `crawler/hymns_manual/` as a manual override directory. Files placed there are not overwritten by crawler saves and can be copied back into generated output during the crawl pipeline.

## Main App Architecture

### Entry And Routing

- `lib/main.dart`: app startup, Isar initialization, deep-link routing

### Core Models

- `lib/models/hymn_song.dart`
- `lib/models/verse.dart`
- `lib/models/line.dart`
- `lib/models/segment.dart`
- `lib/models/hymn_db.dart`
- `lib/models/song_list.dart`

### Services

- `lib/services/hymn_loader_service.dart`: loads hymn JSON assets and available book lists
- `lib/services/hymn_db_service.dart`: builds and queries the Isar search index
- `lib/services/song_list_service.dart`: persists lists in `SharedPreferences`
- `lib/services/song_list_share_service.dart`: deep-link import and export
- `lib/services/midi_player_service.dart`: MIDI download, parsing, and playback

### Screens

- `lib/screens/home_screen.dart`
- `lib/screens/hymn_detail_screen.dart`
- `lib/screens/search_screen.dart`
- `lib/screens/song_lists_screen.dart`
- `lib/screens/song_list_detail_screen.dart`
- `lib/screens/categories_screen.dart`
- `lib/screens/category_detail_screen.dart`
- `lib/screens/lyricists_screen.dart`
- `lib/screens/lyricist_detail_screen.dart`
- `lib/screens/guitar_leadsheet_screen.dart`

### Providers

- `lib/providers/song_list_provider.dart`

## Development Notes

- Search data is rebuilt at startup when `HymnDbService._currentDbVersion` changes.
- The app uses `metadata.category` for topical grouping, but uses `bookId` for loading and navigation.
- Song lists replaced the older standalone favorites flow; the default `Favorites` list now fills that role.
- `assets/available_hymns.json` must stay in sync with the generated files in `hymns/`.
- The deep-link formats currently in use are:
  - `https://cicmusic.net/hymn/<bookId>/<number>`
  - `https://cicmusic.net/songlist/<encodedData>`

## Tests

Current Dart tests focus on song-list import and sharing logic:

- `test/song_list_share_service_test.dart`
- `test/song_list_import_test.dart`

Crawler tests cover HTML parsing and manual-edit protection:

- `crawler/tests/test_crawler.py`
- `crawler/tests/test_manual_edits.py`

## Known Gaps

- The tracked repo does not include `hymns/`, so the app will not load hymn content until data is generated or copied in.
- The tracked repo does not include `assets/soundfont.sf2`, so MIDI playback will fail until a soundfont is installed locally.
- There is still exploratory documentation around prebuilt Isar databases, but the live app currently builds its search database on-device from local hymn JSON.
