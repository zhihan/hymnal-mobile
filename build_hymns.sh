#!/bin/bash
#
# Full pipeline: crawl hymns → copy to app → rebuild available_hymns.json
#
# Usage:
#   ./build_hymns.sh              # Full pipeline (crawl all + songbase + build)
#   ./build_hymns.sh --skip-crawl # Skip crawling, just copy and rebuild
#   ./build_hymns.sh --songbase-only # Only crawl songbase + dedup + copy + rebuild
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CRAWLER_DIR="$SCRIPT_DIR/crawler"
HYMNS_DIR="$SCRIPT_DIR/hymns"

SKIP_CRAWL=false
SONGBASE_ONLY=false

for arg in "$@"; do
  case $arg in
    --skip-crawl) SKIP_CRAWL=true ;;
    --songbase-only) SONGBASE_ONLY=true ;;
    --help|-h)
      echo "Usage: ./build_hymns.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --skip-crawl      Skip crawling, just copy crawler/hymns/ to hymns/ and rebuild"
      echo "  --songbase-only   Only crawl songbase.life, dedup, copy, and rebuild"
      echo "  -h, --help        Show this help"
      echo ""
      echo "Full pipeline:"
      echo "  1. Crawl hymnal.net (Chinese + English)"
      echo "  2. Crawl songbase.life (English)"
      echo "  3. Deduplicate and merge songbase into hymnal.net data"
      echo "  4. Convert Chinese hymns to simplified"
      echo "  5. Apply manual edits from crawler/hymns_manual/"
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
    python3 crawl_all.py --skip-chinese --skip-english --skip-convert --skip-manual
  else
    python3 crawl_all.py
  fi

  cd "$SCRIPT_DIR"
else
  echo ""
  echo ">>> Step 1: [SKIPPED] Crawling"
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
