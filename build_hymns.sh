#!/bin/bash
#
# Full pipeline: crawl hymns → copy to app → rebuild available_hymns.json
#
# Usage:
#   ./build_hymns.sh              # Full pipeline (crawl all + songbase + build)
#   ./build_hymns.sh --skip-crawl # Skip crawling, just copy and rebuild
#   ./build_hymns.sh --songbase-only # Only crawl songbase + dedup + copy + rebuild
#   ./build_hymns.sh --skip-midi  # Skip MIDI download/melody extraction (on by default)
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CRAWLER_DIR="$SCRIPT_DIR/crawler"
HYMNS_DIR="$SCRIPT_DIR/hymns"

SKIP_CRAWL=false
SONGBASE_ONLY=false
SKIP_MIDI=false

for arg in "$@"; do
  case $arg in
    --skip-crawl) SKIP_CRAWL=true ;;
    --songbase-only) SONGBASE_ONLY=true ;;
    --skip-midi) SKIP_MIDI=true ;;
    --help|-h)
      echo "Usage: ./build_hymns.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --skip-crawl      Skip crawling, just copy crawler/hymns/ to hymns/ and rebuild"
      echo "  --songbase-only   Only crawl songbase.life, dedup, copy, and rebuild"
      echo "  --skip-midi       Skip MIDI tune download and melody note extraction (on by default)"
      echo "  -h, --help        Show this help"
      echo ""
      echo "Full pipeline:"
      echo "  1. Crawl hymnal.net (Chinese + English)"
      echo "  2. Crawl songbase.life (English)"
      echo "  3. Deduplicate and merge songbase into hymnal.net data"
      echo "  4. Convert Chinese hymns to simplified"
      echo "  5. Download MIDI tunes and embed melody notes (skip with --skip-midi)"
      echo "  6. Copy crawler/hymns/ → hymns/ (app asset directory)"
      echo "  7. Regenerate assets/available_hymns.json"
      exit 0
      ;;
  esac
done

echo "============================================================"
echo "HYMN BUILD PIPELINE"
echo "============================================================"

# Step 1: Crawl (unless skipped)
if [ "$SKIP_CRAWL" = false ]; then
  echo ""
  echo ">>> Step 1: Crawling hymns..."
  cd "$CRAWLER_DIR"

  if [ "$SONGBASE_ONLY" = true ]; then
    # Songbase-only is the fast path (~3 seconds via API): keep it fast by
    # skipping the crawl phases and MIDI extraction alike.
    CRAWL_ARGS=(--skip-chinese --skip-english --skip-convert --skip-midi)
  else
    CRAWL_ARGS=()
  fi

  if [ "$SKIP_MIDI" = true ]; then
    CRAWL_ARGS+=(--skip-midi)
  fi
  python3 crawl_all.py "${CRAWL_ARGS[@]}"

  cd "$SCRIPT_DIR"
else
  echo ""
  echo ">>> Step 1: [SKIPPED] Crawling (MIDI extraction is part of the crawl;"
  echo "    for a MIDI-only refresh run: python3 crawler/extract_midi_notes.py --hymns-dir crawler/hymns)"
fi

# Step 2: Copy crawler output to app hymns directory
echo ""
echo ">>> Step 2: Copying crawler/hymns/ → hymns/"
mkdir -p "$HYMNS_DIR"
cp -r "$CRAWLER_DIR/hymns/"*.json "$HYMNS_DIR/" 2>/dev/null || true
HYMN_COUNT=$(ls "$HYMNS_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
echo "  Copied $HYMN_COUNT hymn files"

# Step 3: Regenerate available_hymns.json
echo ""
echo ">>> Step 3: Regenerating assets/available_hymns.json"
dart run tool/build_database.dart

# Done
echo ""
echo "============================================================"
echo "BUILD COMPLETE"
echo "============================================================"
echo ""
echo "To run the app:"
echo "  flutter run"
echo ""
echo "To build a release:"
echo "  flutter build apk --release"
echo "  flutter build ios"
