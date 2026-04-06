"""
Songbase.life Crawler
Fetches hymns from songbase.life API and converts to our JSON format.
"""

import requests
import json
import os
import re
import logging
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)


class SongbaseCrawler:
    """Crawler for songbase.life hymns and chords."""

    API_URL = "https://songbase.life/api/v2/app_data"

    # Maps songbase book slugs to our bookId system.
    # Only books that share the same numbering with hymnal.net belong here.
    BOOK_MAPPING = {
        'english_hymnal': 'h',
    }

    # Regex for inline chord markers like [G], [Am7], [D/F#], [D-D7]
    CHORD_PATTERN = re.compile(r'\[([^\]]*)\]')

    def __init__(self, cache_file: str = "songbase_raw.json"):
        self.cache_file = cache_file
        self.session = requests.Session()
        self.session.headers.update({
            'Accept': 'application/json',
            'User-Agent': 'HymnalMobile/1.0',
        })
        self._data = None

    def fetch_all_data(self, use_cache: bool = True) -> dict:
        """
        Fetch all song data from the songbase API.

        Args:
            use_cache: If True, use cached data from disk if available.

        Returns:
            Full API response with 'songs' and 'books' keys.
        """
        if self._data is not None:
            return self._data

        if use_cache and os.path.exists(self.cache_file):
            logger.info(f"Loading cached data from {self.cache_file}")
            with open(self.cache_file, 'r', encoding='utf-8') as f:
                self._data = json.load(f)
            return self._data

        logger.info(f"Fetching data from {self.API_URL}")
        response = self.session.get(self.API_URL, timeout=60)
        response.raise_for_status()
        self._data = response.json()

        # Cache to disk
        with open(self.cache_file, 'w', encoding='utf-8') as f:
            json.dump(self._data, f, ensure_ascii=False)
        logger.info(f"Cached {len(self._data.get('songs', []))} songs to {self.cache_file}")

        return self._data

    def build_book_index(self, data: dict) -> Dict[str, Dict[int, int]]:
        """
        Build reverse index: {book_slug: {hymn_number: song_id}}.

        The API gives books[].songs as {song_id: hymn_number}.
        We invert it to {hymn_number: song_id} for lookup by hymn number.
        """
        index = {}
        for book in data.get('books', []):
            slug = book['slug']
            if slug not in self.BOOK_MAPPING:
                continue
            # API format: {str(song_id): hymn_number}
            reverse = {}
            for song_id_str, hymn_number in book['songs'].items():
                reverse[int(hymn_number)] = int(song_id_str)
            index[slug] = reverse
            logger.info(f"Indexed {slug}: {len(reverse)} hymns (#{min(reverse.keys())}-#{max(reverse.keys())})")
        return index

    @classmethod
    def parse_inline_chords(cls, line_text: str) -> List[dict]:
        """
        Parse a single line with inline [chord] markers into segments.

        Example: "What a w[G]onderful [C]change"
        Returns: [
            {"chord": "", "text": "What a w"},
            {"chord": "G", "text": "onderful "},
            {"chord": "C", "text": "change"}
        ]

        Empty chord markers [] are treated as no chord.
        Dash-separated chords like [D-D7] are kept as-is.
        """
        segments = []
        last_end = 0

        for match in cls.CHORD_PATTERN.finditer(line_text):
            chord = match.group(1)
            start = match.start()
            end = match.end()

            # Text before this chord (or from start)
            text_before = line_text[last_end:start]
            if text_before or (not segments and start > 0):
                # Append to previous segment's text, or create empty-chord segment
                if segments and not text_before.strip() == '' and segments[-1]['text'] == '':
                    # Previous segment had no text yet, just set it
                    pass
                if text_before:
                    if segments:
                        segments[-1]['text'] += text_before
                    else:
                        segments.append({"chord": "", "text": text_before})

            # Start new segment for this chord
            if chord:  # Skip empty [] markers
                segments.append({"chord": chord.strip(), "text": ""})
            last_end = end

        # Remaining text after last chord
        remaining = line_text[last_end:]
        if remaining:
            if segments:
                segments[-1]['text'] += remaining
            else:
                segments.append({"chord": "", "text": remaining})

        # If no chords found at all, return the whole line as one segment
        if not segments:
            segments.append({"chord": "", "text": line_text})

        return segments

    @classmethod
    def parse_lyrics(cls, lyrics_text: str) -> Tuple[List[dict], dict]:
        """
        Parse full songbase lyrics text into structured verses and metadata.

        Returns:
            Tuple of (verses list, extra_metadata dict).
            extra_metadata may contain 'capo' if a #Capo line is found.
        """
        extra_metadata = {}
        verses = []

        # Split into sections by double newline
        sections = re.split(r'\n\n+', lyrics_text.strip())

        for section in sections:
            lines = section.split('\n')
            if not lines:
                continue

            # Handle metadata lines starting with #
            content_lines = []
            for line in lines:
                stripped = line.strip()
                if stripped.startswith('#'):
                    # Extract metadata from # comments
                    comment = stripped.lstrip('#').strip()
                    capo_match = re.match(r'[Cc]apo\s+(\d+)', comment)
                    if capo_match:
                        extra_metadata['capo'] = int(capo_match.group(1))
                    elif comment.startswith('Original tune') or comment.startswith('original tune'):
                        extra_metadata['note'] = comment
                    # Skip # lines from verse content
                else:
                    content_lines.append(line)

            if not content_lines:
                continue

            # Detect verse type and number
            first_line = content_lines[0]
            first_stripped = first_line.strip()

            # Check if this is a numbered verse (starts with digit)
            verse_num_match = re.match(r'^(\d+)\s*$', first_stripped)
            if verse_num_match:
                # Standalone number line - it's a verse number header
                verse_number = verse_num_match.group(1)
                content_lines = content_lines[1:]  # Remove the number line
                verse_type = "verse"
            elif re.match(r'^(\d+)\s+\S', first_stripped):
                # Number at start of first content line (e.g., "1 What a wonderful")
                verse_num_match = re.match(r'^(\d+)\s+', first_stripped)
                verse_number = verse_num_match.group(1)
                content_lines[0] = first_stripped[verse_num_match.end():]
                verse_type = "verse"
            else:
                verse_number = None
                # Check if lines are indented (chorus)
                if content_lines and all(
                    line.startswith('  ') or line.startswith('\t') or line.strip() == ''
                    for line in content_lines if line.strip()
                ):
                    verse_type = "chorus"
                else:
                    verse_type = "verse"

            # Parse each line into segments
            parsed_lines = []
            for line in content_lines:
                text = line.strip()
                if not text:
                    continue
                segments = cls.parse_inline_chords(text)
                parsed_lines.append({"segments": segments})

            if parsed_lines:
                verse = {
                    "type": verse_type,
                    "lines": parsed_lines,
                }
                if verse_number is not None:
                    verse["number"] = verse_number
                verses.append(verse)

        return verses, extra_metadata

    def convert_song(self, song: dict, book_slug: str, hymn_number: int) -> dict:
        """
        Convert a songbase song to our JSON format.

        Args:
            song: Raw song dict from the API.
            book_slug: The songbase book slug (e.g., 'english_hymnal').
            hymn_number: The hymn number in the book.

        Returns:
            Dict in our standard hymn JSON format.
        """
        lyrics = song.get('lyrics', '')
        verses, extra_metadata = self.parse_lyrics(lyrics)

        metadata = {
            "source": "songbase",
            "songbase_id": song['id'],
        }
        if extra_metadata:
            metadata.update(extra_metadata)

        return {
            "url": f"https://songbase.life/song/{song['id']}",
            "title": song['title'],
            "verses": verses,
            "metadata": metadata,
        }

    def crawl_book(
        self,
        book_slug: str,
        output_dir: str = "hymns_songbase",
        use_cache: bool = True,
    ) -> dict:
        """
        Crawl all songs for a given book and save as JSON files.

        Args:
            book_slug: Songbase book slug (e.g., 'english_hymnal').
            output_dir: Directory to save output JSON files.
            use_cache: Whether to use cached API data.

        Returns:
            Dict with statistics: {book_slug, book_id, total, converted, errors}.
        """
        if book_slug not in self.BOOK_MAPPING:
            raise ValueError(f"Unknown book slug: {book_slug}. Supported: {list(self.BOOK_MAPPING.keys())}")

        book_id = self.BOOK_MAPPING[book_slug]
        os.makedirs(output_dir, exist_ok=True)

        data = self.fetch_all_data(use_cache=use_cache)
        book_index = self.build_book_index(data)

        if book_slug not in book_index:
            logger.warning(f"Book {book_slug} not found in API data")
            return {"book_slug": book_slug, "book_id": book_id, "total": 0, "converted": 0, "errors": 0}

        # Build song lookup by ID
        songs_by_id = {s['id']: s for s in data['songs']}
        hymn_index = book_index[book_slug]

        stats = {"book_slug": book_slug, "book_id": book_id, "total": len(hymn_index), "converted": 0, "errors": 0}

        for hymn_number in sorted(hymn_index.keys()):
            song_id = hymn_index[hymn_number]
            song = songs_by_id.get(song_id)

            if not song:
                logger.warning(f"Song ID {song_id} not found for {book_id}_{hymn_number}")
                stats["errors"] += 1
                continue

            try:
                hymn_data = self.convert_song(song, book_slug, hymn_number)
                filename = f"{book_id}_{hymn_number}.json"
                filepath = os.path.join(output_dir, filename)

                with open(filepath, 'w', encoding='utf-8') as f:
                    json.dump(hymn_data, f, ensure_ascii=False, indent=2)

                stats["converted"] += 1
            except Exception as e:
                logger.error(f"Error converting {book_id}_{hymn_number}: {e}")
                stats["errors"] += 1

        logger.info(
            f"Crawled {book_slug}: {stats['converted']}/{stats['total']} converted, "
            f"{stats['errors']} errors"
        )
        return stats

    def crawl_extra_english(
        self,
        output_dir: str = "hymns_songbase",
        use_cache: bool = True,
    ) -> dict:
        """
        Crawl all English songs NOT already in english_hymnal.

        These are saved as sb_{songbase_id}.json. Includes songs from
        blue_songbook and bookless songs.

        Returns:
            Stats dict: {book_id, total, converted, errors}.
        """
        os.makedirs(output_dir, exist_ok=True)
        data = self.fetch_all_data(use_cache=use_cache)

        # Collect all song IDs that are in english_hymnal
        english_hymnal_ids = set()
        for book in data.get('books', []):
            if book['slug'] == 'english_hymnal':
                english_hymnal_ids = set(int(k) for k in book['songs'].keys())
                break

        # Find all English songs not in english_hymnal
        extra_songs = [
            s for s in data['songs']
            if s.get('lang') == 'english' and s['id'] not in english_hymnal_ids
        ]

        stats = {"book_id": "sb", "total": len(extra_songs), "converted": 0, "errors": 0}

        for song in extra_songs:
            try:
                hymn_data = self.convert_song(song, "sb", song['id'])
                filename = f"sb_{song['id']}.json"
                filepath = os.path.join(output_dir, filename)

                with open(filepath, 'w', encoding='utf-8') as f:
                    json.dump(hymn_data, f, ensure_ascii=False, indent=2)

                stats["converted"] += 1
            except Exception as e:
                logger.error(f"Error converting sb_{song['id']}: {e}")
                stats["errors"] += 1

        logger.info(
            f"Crawled extra English: {stats['converted']}/{stats['total']} converted, "
            f"{stats['errors']} errors"
        )
        return stats

    def crawl_all_books(self, output_dir: str = "hymns_songbase", use_cache: bool = True) -> List[dict]:
        """
        Crawl all mapped books plus extra English songs.

        Returns:
            List of stats dicts, one per book plus one for extra English.
        """
        data = self.fetch_all_data(use_cache=use_cache)
        results = []
        for book_slug in self.BOOK_MAPPING:
            result = self.crawl_book(book_slug, output_dir=output_dir, use_cache=use_cache)
            results.append(result)

        # Crawl extra English songs as sb_*
        result = self.crawl_extra_english(output_dir=output_dir, use_cache=use_cache)
        results.append(result)

        return results
