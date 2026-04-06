"""Tests for the SongbaseCrawler."""

import pytest
from songbase_crawler import SongbaseCrawler


class TestParseInlineChords:
    """Tests for parse_inline_chords()."""

    def test_basic_chords(self):
        segments = SongbaseCrawler.parse_inline_chords("What a w[G]onderful [C]change")
        assert len(segments) == 3
        assert segments[0] == {"chord": "", "text": "What a w"}
        assert segments[1] == {"chord": "G", "text": "onderful "}
        assert segments[2] == {"chord": "C", "text": "change"}

    def test_no_chords(self):
        segments = SongbaseCrawler.parse_inline_chords("No chords here")
        assert len(segments) == 1
        assert segments[0] == {"chord": "", "text": "No chords here"}

    def test_chord_at_start(self):
        segments = SongbaseCrawler.parse_inline_chords("[G]Glory be to [C]God")
        assert len(segments) == 2
        assert segments[0] == {"chord": "G", "text": "Glory be to "}
        assert segments[1] == {"chord": "C", "text": "God"}

    def test_empty_chord_marker(self):
        """Empty [] markers should be ignored."""
        segments = SongbaseCrawler.parse_inline_chords("[]Right foot")
        assert len(segments) == 1
        assert segments[0] == {"chord": "", "text": "Right foot"}

    def test_dash_chord(self):
        """Dash-separated chords like [D-D7] should be kept as-is."""
        segments = SongbaseCrawler.parse_inline_chords("[D-D7]Ever [G]One")
        assert len(segments) == 2
        assert segments[0] == {"chord": "D-D7", "text": "Ever "}
        assert segments[1] == {"chord": "G", "text": "One"}

    def test_space_in_chord_is_stripped(self):
        """Chords with leading/trailing spaces should be stripped."""
        segments = SongbaseCrawler.parse_inline_chords("[ G]text")
        assert segments[0]["chord"] == "G"

    def test_complex_chord_names(self):
        segments = SongbaseCrawler.parse_inline_chords("[Am7]hello [D/F#]world")
        assert segments[0]["chord"] == "Am7"
        assert segments[1]["chord"] == "D/F#"

    def test_consecutive_chords(self):
        segments = SongbaseCrawler.parse_inline_chords("[G][C]text")
        # G has empty text, C has "text"
        assert any(s["chord"] == "G" for s in segments)
        assert any(s["chord"] == "C" and "text" in s["text"] for s in segments)


class TestParseLyrics:
    """Tests for parse_lyrics()."""

    def test_basic_verse(self):
        lyrics = "1\nFirst line of verse one\nSecond line"
        verses, meta = SongbaseCrawler.parse_lyrics(lyrics)
        assert len(verses) == 1
        assert verses[0]["type"] == "verse"
        assert verses[0]["number"] == "1"
        assert len(verses[0]["lines"]) == 2

    def test_chorus_detection(self):
        """Indented lines should be detected as chorus."""
        lyrics = "1\nVerse text\n\n  Chorus line one\n  Chorus line two"
        verses, meta = SongbaseCrawler.parse_lyrics(lyrics)
        assert len(verses) == 2
        assert verses[0]["type"] == "verse"
        assert verses[1]["type"] == "chorus"

    def test_multiple_verses(self):
        lyrics = "1\nFirst verse\n\n2\nSecond verse\n\n3\nThird verse"
        verses, meta = SongbaseCrawler.parse_lyrics(lyrics)
        assert len(verses) == 3
        assert verses[0]["number"] == "1"
        assert verses[1]["number"] == "2"
        assert verses[2]["number"] == "3"

    def test_capo_metadata(self):
        lyrics = "#Capo 1\n\n1\nVerse text"
        verses, meta = SongbaseCrawler.parse_lyrics(lyrics)
        assert meta["capo"] == 1
        assert len(verses) == 1  # # line should not create a verse

    def test_comment_lines_skipped(self):
        """# lines like scripture references should be skipped."""
        lyrics = "# Rev. 22:16-17\n# Capo 2\n\n1\n[G]Verse text"
        verses, meta = SongbaseCrawler.parse_lyrics(lyrics)
        assert meta["capo"] == 2
        assert len(verses) == 1
        assert verses[0]["lines"][0]["segments"][0]["chord"] == "G"

    def test_original_tune_note(self):
        lyrics = "###Original tune\n1\nVerse text"
        verses, meta = SongbaseCrawler.parse_lyrics(lyrics)
        assert "note" in meta

    def test_inline_verse_number(self):
        """Verse number on same line as text: '1 What a wonderful'."""
        lyrics = "1 What a wonderful change"
        verses, meta = SongbaseCrawler.parse_lyrics(lyrics)
        assert verses[0]["number"] == "1"
        text = verses[0]["lines"][0]["segments"][0]["text"]
        assert "What" in text

    def test_chords_in_verses(self):
        lyrics = "1\n[G]Glory be to [C]God"
        verses, meta = SongbaseCrawler.parse_lyrics(lyrics)
        segments = verses[0]["lines"][0]["segments"]
        assert segments[0]["chord"] == "G"
        assert segments[1]["chord"] == "C"


class TestConvertSong:
    """Tests for convert_song()."""

    def test_basic_conversion(self):
        crawler = SongbaseCrawler()
        song = {
            "id": 196,
            "title": "Test Hymn",
            "lang": "english",
            "lyrics": "1\n[G]First line\n\n2\nSecond verse",
        }
        result = crawler.convert_song(song, "english_hymnal", 1)
        assert result["title"] == "Test Hymn"
        assert result["url"] == "https://songbase.life/song/196"
        assert len(result["verses"]) == 2
        assert result["metadata"]["source"] == "songbase"
        assert result["metadata"]["songbase_id"] == 196

    def test_capo_in_metadata(self):
        crawler = SongbaseCrawler()
        song = {
            "id": 1,
            "title": "With Capo",
            "lang": "english",
            "lyrics": "#Capo 3\n\n1\nVerse text",
        }
        result = crawler.convert_song(song, "english_hymnal", 1)
        assert result["metadata"]["capo"] == 3


class TestBuildBookIndex:
    """Tests for build_book_index()."""

    def test_builds_reverse_mapping(self):
        crawler = SongbaseCrawler()
        data = {
            "books": [
                {
                    "slug": "english_hymnal",
                    "name": "Hymnal",
                    "songs": {"196": 1, "973": 10, "1061": 100},
                }
            ]
        }
        index = crawler.build_book_index(data)
        assert "english_hymnal" in index
        # Values are reversed: hymn_number -> song_id
        assert index["english_hymnal"][1] == 196
        assert index["english_hymnal"][10] == 973
        assert index["english_hymnal"][100] == 1061

    def test_skips_unmapped_books(self):
        crawler = SongbaseCrawler()
        data = {
            "books": [
                {"slug": "korean_hymnal", "name": "Korean", "songs": {"1": 1}},
                {"slug": "english_hymnal", "name": "Hymnal", "songs": {"1": 1}},
            ]
        }
        index = crawler.build_book_index(data)
        assert "korean_hymnal" not in index
        assert "english_hymnal" in index
