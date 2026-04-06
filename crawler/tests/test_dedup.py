"""Tests for the deduplication and merge logic."""

import pytest
from dedup_hymns import normalize_lyrics, are_lyrics_same, merge_versions


def _make_hymn(text_lines, chords=None):
    """Helper to create a hymn dict with given text lines."""
    segments = []
    for i, text in enumerate(text_lines):
        chord = chords[i] if chords and i < len(chords) else ""
        segments.append({"chord": chord, "text": text})
    return {
        "title": "Test Hymn",
        "url": "https://example.com",
        "verses": [
            {
                "type": "verse",
                "lines": [{"segments": segments}],
            }
        ],
    }


class TestNormalizeLyrics:
    def test_basic_normalization(self):
        hymn = _make_hymn(["Hello, World!"])
        result = normalize_lyrics(hymn)
        assert result == "hello world"

    def test_ignores_chords(self):
        hymn = _make_hymn(["Amazing ", "grace"], ["G", "C"])
        result = normalize_lyrics(hymn)
        assert result == "amazing grace"

    def test_normalizes_curly_quotes(self):
        hymn = _make_hymn(["\u2018It\u2019s a test\u201d"])
        result = normalize_lyrics(hymn)
        assert "its a test" in result

    def test_normalizes_em_dash(self):
        """Em-dash is normalized then stripped as punctuation."""
        hymn = _make_hymn(["word\u2014other"])
        result = normalize_lyrics(hymn)
        # Em-dash → hyphen → stripped by punctuation removal
        assert "wordother" in result

    def test_collapses_whitespace(self):
        hymn = _make_hymn(["  lots   of   spaces  "])
        result = normalize_lyrics(hymn)
        assert result == "lots of spaces"


class TestAreLyricsSame:
    def test_identical(self):
        a = _make_hymn(["Same text here"])
        b = _make_hymn(["Same text here"])
        assert are_lyrics_same(a, b) is True

    def test_different_chords_same_text(self):
        """Same lyrics with different chords should be considered same."""
        a = _make_hymn(["Amazing grace"], ["G"])
        b = _make_hymn(["Amazing grace"], ["C"])
        assert are_lyrics_same(a, b) is True

    def test_different_text(self):
        a = _make_hymn(["First version"])
        b = _make_hymn(["Second version"])
        assert are_lyrics_same(a, b) is False

    def test_punctuation_differences_ignored(self):
        a = _make_hymn(["Hello, world!"])
        b = _make_hymn(["Hello world"])
        assert are_lyrics_same(a, b) is True

    def test_case_differences_ignored(self):
        a = _make_hymn(["HELLO WORLD"])
        b = _make_hymn(["hello world"])
        assert are_lyrics_same(a, b) is True


class TestMergeVersions:
    def test_same_lyrics_no_alternate(self):
        hymnal = _make_hymn(["Same text"])
        hymnal["metadata"] = {"source": "hymnal_net"}
        songbase = _make_hymn(["Same text"])
        songbase["metadata"] = {"source": "songbase"}
        songbase["url"] = "https://songbase.life/song/1"

        result = merge_versions(hymnal, songbase)
        assert "alternate_versions" not in result
        assert result["metadata"]["source"] == "hymnal_net"

    def test_different_lyrics_adds_alternate(self):
        hymnal = _make_hymn(["Original text"])
        hymnal["metadata"] = {"source": "hymnal_net"}
        songbase = {
            "title": "Alt Title",
            "url": "https://songbase.life/song/1",
            "verses": [{"type": "verse", "lines": [{"segments": [{"chord": "", "text": "Different text"}]}]}],
        }

        result = merge_versions(hymnal, songbase)
        assert "alternate_versions" in result
        assert len(result["alternate_versions"]) == 1
        alt = result["alternate_versions"][0]
        assert alt["source"] == "songbase"
        assert alt["title"] == "Alt Title"
        assert alt["url"] == "https://songbase.life/song/1"
        assert len(alt["verses"]) == 1

    def test_no_duplicate_alternates(self):
        """Merging twice should not duplicate the alternate version."""
        hymnal = _make_hymn(["Original text"])
        hymnal["metadata"] = {"source": "hymnal_net"}
        songbase = {
            "title": "Alt",
            "url": "https://songbase.life/song/1",
            "verses": [{"type": "verse", "lines": [{"segments": [{"chord": "", "text": "Different"}]}]}],
        }

        result1 = merge_versions(hymnal, songbase)
        result2 = merge_versions(result1, songbase)
        assert len(result2["alternate_versions"]) == 1
