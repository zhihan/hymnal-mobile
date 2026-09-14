"""Phase 7 failure must fail the pipeline loudly, not hide in the summary."""

import pytest

import crawl_all
from extract_midi_notes import MidiExtractionError


def test_phase7_mass_failure_raises(tmp_path, monkeypatch):
    def fail(*args, **kwargs):
        raise MidiExtractionError(
            "3/3 hymn files failed (100.0% error rate exceeds 10% allowed)",
            {"updated": 0, "unchanged": 0, "skipped": 0, "errors": 3},
        )

    monkeypatch.setattr(crawl_all, "extract_midi_notes", fail)

    with pytest.raises(RuntimeError, match="Phase 7"):
        crawl_all.crawl_all(
            output_dir=str(tmp_path),
            skip_chinese=True,
            skip_english=True,
            skip_songbase=True,
            skip_convert=True,
            skip_manual=True,
            extract_midi=True,
        )
