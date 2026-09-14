#!/usr/bin/env python3
"""One-off migration: bring existing hymn JSON files to the #19 asset format.

For every hymn JSON in --hymns-dir:
  - re-encode v1 melodies to the compact v2 format
    ({"version": 1, ..., "notes": [...]} -> {"v": 2, "ts": [...], "n": [...]});
  - drop the top-level "raw_sections" field (no longer emitted, never read);
  - rewrite the file with compact JSON (no indent).

The melody conversion is lossless (v1 start times are exactly
reconstructible from the v2 encoding) and needs no network access. Files
already on v2, or without a melody, are still compacted and stripped of
raw_sections.

Usage:
    python3 migrate_melody_v2.py --hymns-dir hymns
    python3 migrate_melody_v2.py --hymns-dir hymns --dry-run
"""

from __future__ import annotations

import argparse
import json
import logging
from pathlib import Path

from extract_midi_notes import _encode_melody_v2

LOGGER = logging.getLogger(__name__)


def migrate_file(path: Path, dry_run: bool = False) -> str:
    """Normalize one hymn file to the #19 asset format.

    Converts a v1 melody to v2 when present, drops "raw_sections", and
    rewrites the file with compact JSON. Returns 'migrated' if the melody
    was converted, 'already_v2' if the melody was already v2, 'no_melody'
    if there is no melody, or 'skipped' on any problem.
    """
    data = json.loads(path.read_text(encoding="utf-8"))
    metadata = data.get("metadata") or {}
    melody = metadata.get("melody")
    if not isinstance(melody, dict):
        status = "no_melody"
    elif melody.get("v") == 2:
        status = "already_v2"
    elif melody.get("version") == 1 and isinstance(melody.get("notes"), list):
        signature = melody.get("time_signature")
        if not (isinstance(signature, list) and len(signature) == 2):
            signature = [4, 4]
        metadata["melody"] = {
            "v": 2,
            "ts": list(signature),
            "n": _encode_melody_v2(melody["notes"]),
        }
        data["metadata"] = metadata
        status = "migrated"
    else:
        LOGGER.warning("Unrecognized melody format in %s; skipping", path.name)
        return "skipped"

    data.pop("raw_sections", None)
    if not dry_run:
        path.write_text(
            json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )
    return status


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hymns-dir", default="hymns")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would change without writing files",
    )
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    counts = {"migrated": 0, "already_v2": 0, "no_melody": 0, "skipped": 0}
    paths = sorted(Path(args.hymns_dir).glob("*.json"))
    for path in paths:
        try:
            counts[migrate_file(path, dry_run=args.dry_run)] += 1
        except Exception as error:
            counts["skipped"] += 1
            LOGGER.warning("Could not migrate %s: %s", path.name, error)

    print(json.dumps({"total": len(paths), **counts}, indent=2))
    if args.dry_run:
        print("(dry run: no files were written)")


if __name__ == "__main__":
    main()
