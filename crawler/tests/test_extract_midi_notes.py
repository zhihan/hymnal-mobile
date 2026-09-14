import io
import json
import sys

import mido
import pytest

import extract_midi_notes
from extract_midi_notes import (
    SCHEMA_VERSION,
    USER_AGENT,
    MidiExtractionError,
    _encode_melody_v2,
    _format_duration,
    extract_melody,
    main,
    process_directory,
    process_hymn,
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

    assert melody["v"] == 2
    assert melody["n"] == [[480, 60], [240, 2]]


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

    assert melody["v"] == 2
    # The monophonic track (index 1) wins over the chord track; the second
    # entry carries the pitch delta from the first.
    assert melody["n"] == [[240, 60], [240, 2]]


def test_formats_progress_eta():
    assert _format_duration(65) == "1m 05s"
    assert _format_duration(3661) == "1h 01m 01s"


def _write_hymn(path, metadata):
    path.write_text(json.dumps({"metadata": metadata}), encoding="utf-8")


def _write_hymn_json(path, metadata):
    _write_hymn(path, metadata)


def _midi_bytes():
    midi = _midi_with_tracks([
        mido.Message("note_on", note=60, velocity=64, time=0),
        mido.Message("note_off", note=60, velocity=0, time=480),
    ])
    buffer = io.BytesIO()
    midi.save(file=buffer)
    return buffer.getvalue()


class _FakeResponse:
    def __init__(self, content):
        self.content = content

    def raise_for_status(self):
        pass


class _FakeSession:
    def __init__(self, content):
        self.content = content
        self.gets = 0

    def get(self, url, timeout=None):
        self.gets += 1
        return _FakeResponse(self.content)


class _NoGetSession:
    def get(self, *args, **kwargs):
        raise AssertionError("no HTTP request should be made")


def test_process_hymn_skips_download_when_melody_current(tmp_path):
    path = tmp_path / "h_1.json"
    _write_hymn(path, {
        "midi_tune_url": "https://www.hymnal.net/midi/tunes/h001.mid",
        "melody": {"v": SCHEMA_VERSION, "n": []},
    })

    assert process_hymn(path, _NoGetSession()) == "unchanged"


def test_process_hymn_force_redownloads_current_melody(tmp_path):
    path = tmp_path / "h_1.json"
    _write_hymn(path, {
        "midi_tune_url": "https://www.hymnal.net/midi/tunes/h001.mid",
        "melody": {"v": SCHEMA_VERSION, "n": []},
    })
    session = _FakeSession(_midi_bytes())

    assert process_hymn(path, session, force=True) == "updated"
    assert session.gets == 1


def test_process_hymn_sleeps_only_before_actual_download(tmp_path, monkeypatch):
    sleeps = []
    monkeypatch.setattr(extract_midi_notes.time, "sleep", sleeps.append)

    path = tmp_path / "h_1.json"
    _write_hymn(path, {"midi_tune_url": "https://www.hymnal.net/midi/tunes/h001.mid"})

    assert process_hymn(path, _FakeSession(_midi_bytes()), delay=0.5) == "updated"
    assert sleeps == [0.5]


def test_process_directory_sets_user_agent_and_skips_quietly(tmp_path, monkeypatch):
    sessions = []

    class FakeSession:
        def __init__(self):
            self.headers = {}
            sessions.append(self)

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

    monkeypatch.setattr(extract_midi_notes.requests, "Session", FakeSession)
    sleeps = []
    monkeypatch.setattr(extract_midi_notes.time, "sleep", sleeps.append)

    _write_hymn(tmp_path / "h_1.json", {})
    _write_hymn(tmp_path / "h_2.json", {
        "midi_tune_url": "https://www.hymnal.net/midi/tunes/h002.mid",
        "melody": {"v": SCHEMA_VERSION, "n": []},
    })

    result = process_directory(tmp_path, delay=0.5, progress_every=0)

    assert result == {"updated": 0, "unchanged": 1, "skipped": 1, "errors": 0}
    assert sessions[0].headers["User-Agent"] == USER_AGENT
    assert "python-requests" not in sessions[0].headers["User-Agent"]
    assert sleeps == []


class _FailingSession:
    def __init__(self, *args, **kwargs):
        self.headers = {}

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def get(self, *args, **kwargs):
        raise RuntimeError("403 Forbidden")


def _patch_failing_session(monkeypatch):
    monkeypatch.setattr(extract_midi_notes.requests, "Session", _FailingSession)


def test_process_directory_raises_when_all_fail(tmp_path, monkeypatch):
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


def test_process_directory_skipped_do_not_dilute_error_rate(tmp_path, monkeypatch):
    _patch_failing_session(monkeypatch)
    for i in range(9):
        _write_hymn_json(tmp_path / f"s_{i}.json", {})
    _write_hymn_json(
        tmp_path / "h_0.json",
        {"midi_tune_url": "https://www.hymnal.net/midi/tunes/h0.mid"},
    )

    with pytest.raises(MidiExtractionError):
        process_directory(tmp_path, progress_every=0)


def test_process_directory_tolerates_few_errors(tmp_path, monkeypatch):
    _patch_failing_session(monkeypatch)
    for i in range(9):
        _write_hymn_json(
            tmp_path / f"u_{i}.json",
            {
                "midi_tune_url": f"https://www.hymnal.net/midi/tunes/u{i}.mid",
                "melody": {"v": SCHEMA_VERSION, "n": []},
            },
        )
    _write_hymn_json(
        tmp_path / "h_0.json",
        {"midi_tune_url": "https://www.hymnal.net/midi/tunes/h0.mid"},
    )

    result = process_directory(tmp_path, progress_every=0)

    assert result["errors"] == 1
    assert result["unchanged"] == 9


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
def test_encode_melody_v2_contiguous_notes():
    notes = [
        {"start": 0, "duration": 384, "pitch": 60},
        {"start": 384, "duration": 192, "pitch": 62},
        {"start": 576, "duration": 192, "pitch": 59},
    ]
    assert _encode_melody_v2(notes) == [[384, 60], [192, 2], [192, -3]]


def test_encode_melody_v2_inserts_rest_for_gap():
    notes = [
        {"start": 0, "duration": 384, "pitch": 60},
        {"start": 768, "duration": 384, "pitch": 65},
    ]
    assert _encode_melody_v2(notes) == [[384, 60], ["R", 384], [384, 5]]


def _decode_melody_v2(encoded):
    """Python mirror of Melody.fromJson; used to verify round-trips."""
    notes = []
    cursor = 0
    pitch = None
    for entry in encoded:
        if entry[0] == "R":
            cursor += entry[1]
            continue
        duration, delta = entry
        pitch = delta if pitch is None else pitch + delta
        notes.append({"start": cursor, "duration": duration, "pitch": pitch})
        cursor += duration
    return notes


def test_encode_melody_v2_roundtrip():
    notes = [
        {"start": 0, "duration": 384, "pitch": 60},
        {"start": 384, "duration": 192, "pitch": 62},
        {"start": 576, "duration": 192, "pitch": 60},
        {"start": 960, "duration": 768, "pitch": 65},
    ]
    assert _decode_melody_v2(_encode_melody_v2(notes)) == notes


def test_extract_melody_returns_v2_shape():
    midi = mido.MidiFile(ticks_per_beat=384)
    track = mido.MidiTrack()
    track.append(mido.Message("note_on", note=60, velocity=64, time=0))
    track.append(mido.Message("note_off", note=60, velocity=64, time=384))
    track.append(mido.Message("note_on", note=62, velocity=64, time=0))
    track.append(mido.Message("note_off", note=62, velocity=64, time=192))
    midi.tracks.append(track)

    melody = extract_melody(midi)

    assert melody["v"] == 2
    assert set(melody) == {"v", "n"}
    assert _decode_melody_v2(melody["n"]) == [
        {"start": 0, "duration": 384, "pitch": 60},
        {"start": 384, "duration": 192, "pitch": 62},
    ]
