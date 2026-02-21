#!/bin/bash
# Check progress of ch hymn crawler

echo "=== Crawler Progress ==="
echo ""
echo "Latest log entries:"
tail -5 crawl_ch.log
echo ""
echo "Files saved so far:"
ls hymns/ch_*.json 2>/dev/null | wc -l | xargs echo "JSON files:"
ls hymns/ch_*.txt 2>/dev/null | wc -l | xargs echo "TXT files:"
echo ""
echo "Process status:"
pgrep -f "crawl_ch_hymns.py" > /dev/null && echo "✓ Crawler is running" || echo "✗ Crawler is not running"
