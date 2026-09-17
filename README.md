# Hymnal Mobile

Flutter app for browsing hymns with inline chords, full-text search, song lists,
guitar leadsheets, and on-device guitar tablature.

The repository has two parts:

- `./` — the Flutter app
- `./crawler` — a Python crawler that fetches hymn data from hymnal.net and
  songbase.life and writes the JSON files the app bundles

## Prerequisites

- Flutter SDK
- Python 3.12+
- Xcode (iOS) and/or Android Studio + Android SDK

## Setup

Python crawler:

```bash
cd crawler
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd ..
```

Flutter app:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

The second command generates `lib/models/hymn_db.g.dart` (the Isar database
schema). It's gitignored, so a fresh checkout won't build without it — rerun
it whenever `lib/models/hymn_db.dart` changes.

## Build The Hymn Data

One command does everything — crawl all sources, extract MIDI melodies, copy the
result into the app's asset directory, and regenerate the manifest:

```bash
source crawler/venv/bin/activate    # build_hymns.sh calls plain `python3`
./build_hymns.sh
```

That runs:

1. Crawl hymnal.net (Chinese + English)
2. Crawl songbase.life
3. Deduplicate and merge songbase into the hymnal.net data
4. Convert Chinese hymns to simplified
5. Apply hand-fixed hymns from `crawler/hymns_manual/`
6. Download MIDI tunes and embed melody notes into `metadata.melody`
7. Copy `crawler/hymns/` → `hymns/`
8. Regenerate `assets/available_hymns.json`

It takes a while — step 1 crawls ~5,800 pages and step 6 downloads ~4,000 MIDI
files. Both are rate-limited on purpose. Pass `--skip-midi` to skip step 6.

## Run The App

```bash
flutter run
```

Useful commands:

```bash
flutter devices
flutter run -d <device_id>
flutter test
flutter analyze
dart format lib test
```

## Tests

```bash
crawler/venv/bin/python -m pytest crawler/tests/
flutter test
```

## Release Build (Android)

```bash
./build_release.sh
```

Prompts for a version bump, then produces the Play Store bundle at
`build/app/outputs/bundle/release/app-release.aab` and a test APK at
`build/app/outputs/flutter-apk/app-release.apk`. Requires
`android/key.properties` — see `android/CREATE_KEYSTORE.md` to create it, and
`PLAY_STORE_PUBLISHING_GUIDE.md` for the upload steps.

## Data Files

The app loads hymns from two generated inputs, both produced by
`./build_hymns.sh`:

- `hymns/*.json`
- `assets/available_hymns.json`

Both `hymns/` and `assets/available_hymns.json` are gitignored generated
content, so neither will exist in a fresh checkout until you run the build
above.

If `hymns/*.json` already exists (e.g. after hand-editing one hymn) and you
just need to regenerate the manifest without a full recrawl:

```bash
dart run tool/build_database.dart
```

Each file is named `{bookId}_{number}.json`, e.g. `ch_100.json`, `h_500.json`.
Book IDs:

- `ch` — Chinese Classical Hymns
- `ts` — Chinese Supplement
- `h` — English Hymns
- `ns` — New Songs
- `lb` — New Songs (LB)
- `nt` — New Tune
- `sb` — SongBase (from songbase.life)

## Guitar Tablature

Hymns whose source provides a MIDI tune get compact melody data written to
`metadata.melody` during step 6. The app renders that as guitar tablature
on-device, recalculating string and fret positions whenever the capo or
transpose setting changes. Hymns without a MIDI tune simply have no Tab button.

Melodies are stored in a compact v2 encoding:

```json
"melody": {"v": 2, "n": [[384, 60], [192, 2], ["R", 384], [768, 5]]}
```

Each entry is `[duration, pitch]` — the first carries an absolute MIDI pitch,
later entries a delta from the previous note — and `["R", ticks]` is a rest.

To re-extract the melody for a single hymn without rebuilding the catalog:

```bash
crawler/venv/bin/python crawler/extract_midi_notes.py \
  --file crawler/hymns/h_350.json --force
```

To convert an existing crawl from the v1 encoding in place (lossless, no
network):

```bash
crawler/venv/bin/python crawler/migrate_melody_v2.py --hymns-dir crawler/hymns
```

## Development Notes

- The search index is rebuilt at startup when `HymnDbService._currentDbVersion`
  changes.
- Use `bookId` for loading and navigation; `metadata.category` is topical
  grouping only and is not the same thing.
- `assets/available_hymns.json` must stay in sync with `hymns/`.
- Deep-link formats:
  - `https://cicmusic.net/hymn/<bookId>/<number>`
  - `https://cicmusic.net/songlist/<encodedData>`
