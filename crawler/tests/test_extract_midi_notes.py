import mido

from extract_midi_notes import _format_duration, extract_melody


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
