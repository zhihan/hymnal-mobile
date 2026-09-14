"""Phase 7 (MIDI extraction): default-on gating and failure propagation."""

import sys

import pytest

import crawl_all
from extract_midi_notes import MidiExtractionError


def _skipped_phases():
    return dict(
        skip_chinese=True,
        skip_english=True,
        skip_songbase=True,
        skip_convert=True,
        skip_manual=True,
    )


def test_phase7_runs_by_default(tmp_path, monkeypatch):
    calls = []

    def fake_extract(output_dir, **kwargs):
        calls.append((output_dir, kwargs))
        return {"updated": 0, "errors": 0}

    monkeypatch.setattr(crawl_all, "extract_midi_notes", fake_extract)

    crawl_all.crawl_all(output_dir=str(tmp_path), **_skipped_phases())

    assert len(calls) == 1
    assert calls[0][0] == str(tmp_path)
    assert calls[0][1]["delay"] == 0.5


def test_phase7_suppressed_by_skip_midi(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(
        crawl_all, "extract_midi_notes", lambda *a, **k: calls.append(True)
    )

    crawl_all.crawl_all(output_dir=str(tmp_path), skip_midi=True, **_skipped_phases())

    assert calls == []


def test_cli_skip_midi_flag(monkeypatch):
    captured = {}
    monkeypatch.setattr(crawl_all, "crawl_all", lambda **kwargs: captured.update(kwargs))
    monkeypatch.setattr(sys, "argv", ["crawl_all.py", "--skip-midi", "--dry-run"])

    crawl_all.main()

    assert captured["skip_midi"] is True


def test_cli_midi_on_by_default(monkeypatch):
    captured = {}
    monkeypatch.setattr(crawl_all, "crawl_all", lambda **kwargs: captured.update(kwargs))
    monkeypatch.setattr(sys, "argv", ["crawl_all.py", "--dry-run"])

    crawl_all.main()

    assert captured["skip_midi"] is False


def test_phase7_mass_failure_raises(tmp_path, monkeypatch):
    def fail(*args, **kwargs):
        raise MidiExtractionError(
            "3/3 attempted hymn downloads failed (100.0% error rate exceeds 10% allowed)",
            {"updated": 0, "unchanged": 0, "skipped": 0, "errors": 3},
        )

    monkeypatch.setattr(crawl_all, "extract_midi_notes", fail)

    with pytest.raises(RuntimeError, match="Phase 7"):
        crawl_all.crawl_all(
            output_dir=str(tmp_path),
            **_skipped_phases(),
        )
