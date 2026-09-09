#!/usr/bin/env python3
"""Download hymn MIDI tunes and embed a compact melody representation.

The generated data intentionally contains pitches and timing, not guitar
fingerings.  Fingering depends on capo position and is calculated by the app.
"""

import argparse
import io
import json
import logging
import time
from pathlib import Path
from typing import Iterable

import mido
import requests


LOGGER = logging.getLogger(__name__)
SCHEMA_VERSION = 1


def _track_notes(track: mido.MidiTrack) -> list[dict]:
    tick = 0
    active: dict[tuple[int, int], list[int]] = {}
    notes: list[dict] = []

    for message in track:
        tick += message.time
        if message.type == "note_on" and message.velocity > 0:
            active.setdefault((message.channel, message.note), []).append(tick)
        elif message.type in ("note_off", "note_on"):
            starts = active.get((message.channel, message.note))
            if not starts:
                continue
            start = starts.pop(0)
            notes.append({
                "start": start,
                "duration": max(1, tick - start),
                "pitch": message.note,
            })

    return sorted(notes, key=lambda note: (note["start"], note["pitch"]))


def _overlap_count(notes: list[dict]) -> int:
    """Count notes that overlap their predecessor (a polyphony indicator)."""
    overlaps = 0
    latest_end = -1
    for note in notes:
        if note["start"] < latest_end:
            overlaps += 1
        latest_end = max(latest_end, note["start"] + note["duration"])
    return overlaps


def extract_melody(midi: mido.MidiFile) -> dict:
    """Extract the most melody-like non-empty track from a MIDI file."""
    candidates = []
    for index, track in enumerate(midi.tracks):
        notes = _track_notes(track)
        if notes:
            candidates.append((notes, index))

    if not candidates:
        raise ValueError("MIDI contains no notes")

    # Prefer monophonic tracks, then the track containing the most notes.
    notes, track_index = min(
        candidates,
        key=lambda item: (
            _overlap_count(item[0]) / len(item[0]),
            -len(item[0]),
            item[1],
        ),
    )

    tempo = 500_000
    numerator, denominator = 4, 4
    found_tempo = False
    found_signature = False
    for track in midi.tracks:
        for message in track:
            if message.type == "set_tempo" and not found_tempo:
                tempo = message.tempo
                found_tempo = True
            if message.type == "time_signature" and not found_signature:
                numerator, denominator = message.numerator, message.denominator
                found_signature = True

    return {
        "version": SCHEMA_VERSION,
        "ticks_per_beat": midi.ticks_per_beat,
        "tempo_bpm": round(mido.tempo2bpm(tempo), 2),
        "time_signature": [numerator, denominator],
        "track": track_index,
        "notes": notes,
    }


def process_hymn(path: Path, session: requests.Session, timeout: float = 20) -> str:
    data = json.loads(path.read_text(encoding="utf-8"))
    metadata = data.get("metadata") or {}
    midi_url = metadata.get("midi_tune_url")
    if not midi_url:
        return "skipped"

    response = session.get(midi_url, timeout=timeout)
    response.raise_for_status()
    melody = extract_melody(mido.MidiFile(file=io.BytesIO(response.content)))
    if metadata.get("melody") == melody:
        return "unchanged"

    metadata["melody"] = melody
    data["metadata"] = metadata
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return "updated"


def _format_duration(seconds: float) -> str:
    seconds = max(0, round(seconds))
    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    if hours:
        return f"{hours}h {minutes:02d}m {seconds:02d}s"
    return f"{minutes}m {seconds:02d}s"


def process_directory(
    hymns_dir: str | Path,
    paths: Iterable[Path] | None = None,
    progress_every: int = 25,
) -> dict:
    directory = Path(hymns_dir)
    hymn_paths = list(paths) if paths is not None else sorted(directory.glob("*.json"))
    counts = {"updated": 0, "unchanged": 0, "skipped": 0, "errors": 0}
    total = len(hymn_paths)
    started_at = time.monotonic()
    LOGGER.info("Starting MIDI extraction for %d hymn files", total)

    with requests.Session() as session:
        for processed, path in enumerate(hymn_paths, start=1):
            try:
                counts[process_hymn(path, session)] += 1
            except Exception as error:  # Continue a large batch after one bad MIDI.
                counts["errors"] += 1
                LOGGER.warning("Could not extract %s: %s", path.name, error)

            if progress_every > 0 and (processed % progress_every == 0 or processed == total):
                elapsed = time.monotonic() - started_at
                rate = processed / elapsed if elapsed > 0 else 0
                remaining = (total - processed) / rate if rate > 0 else 0
                LOGGER.info(
                    "Progress %d/%d (%.1f%%) | updated=%d unchanged=%d "
                    "skipped=%d errors=%d | %.1f files/s | ETA %s",
                    processed,
                    total,
                    processed / total * 100 if total else 100,
                    counts["updated"],
                    counts["unchanged"],
                    counts["skipped"],
                    counts["errors"],
                    rate,
                    _format_duration(remaining),
                )

    LOGGER.info("MIDI extraction finished in %s", _format_duration(time.monotonic() - started_at))
    return counts


def main() -> None:
    parser = argparse.ArgumentParser(description="Embed MIDI melody notes in hymn JSON")
    parser.add_argument("--hymns-dir", default="hymns")
    parser.add_argument("--file", action="append", type=Path, help="Process only this JSON file")
    parser.add_argument(
        "--progress-every",
        type=int,
        default=25,
        help="Log progress after this many files; use 0 to disable (default: 25)",
    )
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    result = process_directory(args.hymns_dir, args.file, args.progress_every)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
