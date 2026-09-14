import json

from migrate_melody_v2 import migrate_file


def _write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _v1_file(path):
    _write(
        path,
        {
            "url": "https://www.hymnal.net/en/hymn/h/350",
            "title": "Test",
            "verses": [],
            "metadata": {
                "midi_tune_url": "https://www.hymnal.net/midi/tunes/h350.mid",
                "melody": {
                    "version": 1,
                    "ticks_per_beat": 384,
                    "tempo_bpm": 100.0,
                    "time_signature": [4, 4],
                    "track": 1,
                    "notes": [
                        {"start": 0, "duration": 384, "pitch": 60},
                        {"start": 384, "duration": 192, "pitch": 62},
                        {"start": 768, "duration": 192, "pitch": 60},
                    ],
                },
            },
        },
    )


def _decode_v2(melody):
    notes = []
    cursor = 0
    pitch = None
    for entry in melody["n"]:
        if entry[0] == "R":
            cursor += entry[1]
            continue
        duration, delta = entry
        pitch = delta if pitch is None else pitch + delta
        notes.append({"start": cursor, "duration": duration, "pitch": pitch})
        cursor += duration
    return notes


def test_migrates_v1_to_v2_losslessly(tmp_path):
    path = tmp_path / "h_350.json"
    _v1_file(path)

    assert migrate_file(path) == "migrated"

    data = json.loads(path.read_text(encoding="utf-8"))
    melody = data["metadata"]["melody"]
    assert melody["v"] == 2
    assert set(melody) == {"v", "ts", "n"}
    assert melody["ts"] == [4, 4]
    assert _decode_v2(melody) == [
        {"start": 0, "duration": 384, "pitch": 60},
        {"start": 384, "duration": 192, "pitch": 62},
        {"start": 768, "duration": 192, "pitch": 60},
    ]
    # Untouched fields survive the migration.
    assert data["title"] == "Test"
    assert data["metadata"]["midi_tune_url"].endswith("h350.mid")


def test_migrated_file_is_compact_json(tmp_path):
    path = tmp_path / "h_350.json"
    _v1_file(path)

    migrate_file(path)

    assert "\n  " not in path.read_text(encoding="utf-8")


def test_already_v2_melody_kept_but_file_normalized(tmp_path):
    path = tmp_path / "h_1.json"
    _write(path, {"metadata": {"melody": {"v": 2, "n": [[384, 60]]}},
                  "raw_sections": ["stale"]})

    assert migrate_file(path) == "already_v2"

    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["metadata"]["melody"] == {"v": 2, "n": [[384, 60]]}
    assert "raw_sections" not in data
    assert "\n  " not in path.read_text(encoding="utf-8")


def test_no_melody_file_still_normalized(tmp_path):
    path = tmp_path / "h_2.json"
    _write(path, {"metadata": {}, "raw_sections": ["stale"]})

    assert migrate_file(path) == "no_melody"

    data = json.loads(path.read_text(encoding="utf-8"))
    assert "raw_sections" not in data
    assert "\n  " not in path.read_text(encoding="utf-8")


def test_dry_run_writes_nothing(tmp_path):
    path = tmp_path / "h_350.json"
    _v1_file(path)
    before = path.read_text(encoding="utf-8")

    assert migrate_file(path, dry_run=True) == "migrated"
    assert path.read_text(encoding="utf-8") == before


def test_migration_carries_non_common_time_signature(tmp_path):
    """A 3/4 hymn must stay 3/4 through the v1 -> v2 conversion."""
    path = tmp_path / "ch_13.json"
    _write(path, {"metadata": {"melody": {
        "version": 1,
        "ticks_per_beat": 384,
        "time_signature": [3, 4],
        "notes": [{"start": 0, "duration": 384, "pitch": 60}],
    }}})

    assert migrate_file(path) == "migrated"
    melody = json.loads(path.read_text())["metadata"]["melody"]
    assert melody["ts"] == [3, 4]


def test_migration_defaults_missing_time_signature(tmp_path):
    path = tmp_path / "ch_14.json"
    _write(path, {"metadata": {"melody": {
        "version": 1,
        "notes": [{"start": 0, "duration": 384, "pitch": 60}],
    }}})

    assert migrate_file(path) == "migrated"
    assert json.loads(path.read_text())["metadata"]["melody"]["ts"] == [4, 4]
