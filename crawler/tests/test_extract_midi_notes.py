import sys

import mido
import pytest

from extract_midi_notes import (
    MidiExtractionError,
    _format_duration,
    extract_melody,
    main,
    process_directory,
)


def _midi_with_tracks(*tracks):
    midi = mido.MidiFile(ticks_per_beat=480)
    for messages in tracks:
        track = mido.MidiTrack()
        track.extend(messages)
        midi.tracks.append(track)
    return midi


def test_extracts_pitch_start_and_duration():
    midi = _midi_with_tracks([
        mido.MetaMessage("set_tempo", tempo=600_000, time=0),
        mido.Message("note_on", note=60, velocity=64, time=0),
        mido.Message("note_off", note=60, velocity=0, time=480),
        mido.Message("note_on", note=62, velocity=64, time=0),
        mido.Message("note_off", note=62, velocity=0, time=240),
    ])

    melody = extract_melody(midi)

    assert melody["ticks_per_beat"] == 480
    assert melody["tempo_bpm"] == 100.0
    assert melody["notes"] == [
        {"start": 0, "duration": 480, "pitch": 60},
        {"start": 480, "duration": 240, "pitch": 62},
    ]


def test_prefers_monophonic_track_over_chord_track():
    chord_track = [
        mido.Message("note_on", note=48, velocity=64, time=0),
        mido.Message("note_on", note=52, velocity=64, time=0),
        mido.Message("note_off", note=48, velocity=0, time=480),
        mido.Message("note_off", note=52, velocity=0, time=0),
    ]
    melody_track = [
        mido.Message("note_on", note=60, velocity=64, time=0),
        mido.Message("note_off", note=60, velocity=0, time=240),
        mido.Message("note_on", note=62, velocity=64, time=0),
        mido.Message("note_off", note=62, velocity=0, time=240),
    ]

    melody = extract_melody(_midi_with_tracks(chord_track, melody_track))

    assert melody["track"] == 1
    assert [note["pitch"] for note in melody["notes"]] == [60, 62]


def test_formats_progress_eta():
    assert _format_duration(65) == "1m 05s"
    assert _format_duration(3661) == "1h 01m 01s"


def _write_hymn_json(path, metadata):
    import json

    path.write_text(json.dumps({"metadata": metadata}), encoding="utf-8")


class _FailingSession:
    """Session double whose GET always fails (e.g. hymnal.net 403s)."""

    def __init__(self, *args, **kwargs):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def get(self, *args, **kwargs):
        raise RuntimeError("403 Forbidden")


def _patch_failing_session(monkeypatch):
    import extract_midi_notes

    monkeypatch.setattr(extract_midi_notes.requests, "Session", _FailingSession)


def test_process_directory_raises_when_all_fail(tmp_path, monkeypatch):
    # Issue #17: a 100% failure must not look successful.
    _patch_failing_session(monkeypatch)
    for i in range(3):
        _write_hymn_json(
            tmp_path / f"h_{i}.json",
            {"midi_tune_url": f"https://www.hymnal.net/midi/tunes/h{i}.mid"},
        )

    with pytest.raises(MidiExtractionError) as exc_info:
        process_directory(tmp_path, progress_every=0)

    assert exc_info.value.counts == {
        "updated": 0,
        "unchanged": 0,
        "skipped": 0,
        "errors": 3,
    }


def test_process_directory_tolerates_few_errors(tmp_path, monkeypatch):
    _patch_failing_session(monkeypatch)
    # 9 hymns with no MIDI URL (skipped), 1 failing download: 1/10 = 10%
    # does not exceed the default 10% threshold.
    for i in range(9):
        _write_hymn_json(tmp_path / f"s_{i}.json", {})
    _write_hymn_json(
        tmp_path / "h_0.json",
        {"midi_tune_url": "https://www.hymnal.net/midi/tunes/h0.mid"},
    )

    result = process_directory(tmp_path, progress_every=0)

    assert result["errors"] == 1
    assert result["skipped"] == 9


def test_process_directory_strict_threshold(tmp_path, monkeypatch):
    _patch_failing_session(monkeypatch)
    for i in range(9):
        _write_hymn_json(tmp_path / f"s_{i}.json", {})
    _write_hymn_json(
        tmp_path / "h_0.json",
        {"midi_tune_url": "https://www.hymnal.net/midi/tunes/h0.mid"},
    )

    with pytest.raises(MidiExtractionError):
        process_directory(tmp_path, progress_every=0, max_error_rate=0.0)


def test_process_directory_empty_dir_ok(tmp_path):
    assert process_directory(tmp_path, progress_every=0) == {
        "updated": 0,
        "unchanged": 0,
        "skipped": 0,
        "errors": 0,
    }


def test_main_exits_nonzero_on_mass_failure(tmp_path, monkeypatch, capsys):
    _patch_failing_session(monkeypatch)
    for i in range(3):
        _write_hymn_json(
            tmp_path / f"h_{i}.json",
            {"midi_tune_url": f"https://www.hymnal.net/midi/tunes/h{i}.mid"},
        )
    monkeypatch.setattr(
        sys, "argv", ["extract_midi_notes.py", "--hymns-dir", str(tmp_path)]
    )

    with pytest.raises(SystemExit) as exc_info:
        main()

    assert exc_info.value.code == 1
    assert '"errors": 3' in capsys.readouterr().out
