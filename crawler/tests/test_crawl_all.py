"""Phase 7 (MIDI extraction) gating: default-on, suppressed by --skip-midi."""

import sys

import crawl_all


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
