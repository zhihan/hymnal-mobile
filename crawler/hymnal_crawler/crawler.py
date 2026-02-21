"""
Hymnal.net Crawler
Crawls hymnal.net to download hymns and their chords.
"""

import requests
from bs4 import BeautifulSoup
import json
import os
import time
import re
import logging
from typing import Dict, List, Optional

# Set up logger for this module
logger = logging.getLogger(__name__)


class HymnalCrawler:
    """Crawler for hymnal.net hymns and chords."""

    # Supported hymn categories
    SUPPORTED_CATEGORIES = {
        'h': 'English Hymns',
        'ns': 'New Songs',
        'ch': 'Chinese Classical Hymns',
        'ts': 'Chinese New Hymns',
        'lb': 'New Songs (lb)',
        'nt': 'New Tune'
    }

    # Key to semitone mapping for transpose calculation
    KEY_TO_SEMITONE = {
        'C': 0, 'C Major': 0, 'C minor': 0,
        'C#': 1, 'Db': 1, 'C# Major': 1, 'Db Major': 1, 'C# minor': 1, 'D♭ Major': 1, 'C♯ Major': 1,
        'D': 2, 'D Major': 2, 'D minor': 2,
        'D#': 3, 'Eb': 3, 'D# Major': 3, 'Eb Major': 3, 'D# minor': 3, 'E♭ Major': 3, 'D♯ Major': 3,
        'E': 4, 'E Major': 4, 'E minor': 4,
        'F': 5, 'F Major': 5, 'F minor': 5,
        'F#': 6, 'Gb': 6, 'F# Major': 6, 'Gb Major': 6, 'F# minor': 6, 'G♭ Major': 6, 'F♯ Major': 6,
        'G': 7, 'G Major': 7, 'G minor': 7,
        'G#': 8, 'Ab': 8, 'G# Major': 8, 'Ab Major': 8, 'G# minor': 8, 'A♭ Major': 8, 'G♯ Major': 8,
        'A': 9, 'A Major': 9, 'A minor': 9,
        'A#': 10, 'Bb': 10, 'A# Major': 10, 'Bb Major': 10, 'A# minor': 10, 'B♭ Major': 10, 'A♯ Major': 10,
        'B': 11, 'B Major': 11, 'B minor': 11
    }

    def __init__(self, base_url: str = "https://www.hymnal.net", manual_dir: str = "hymns_manual"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
        # Track fetched hymns to avoid re-fetching
        # Key format: "{language}_{category}_{number}"
        self.fetched_hymns = {}
        # Manual edits directory - hymns here should never be overwritten
        self.manual_dir = manual_dir

    @staticmethod
    def get_language_from_category(category: str) -> str:
        """
        Determine the language code from a hymn category.

        Args:
            category: Category code (e.g., 'h', 'ts', 'ns', 'ch', 'lb', 'nt')

        Returns:
            Language code: 'en' for English categories, 'cn' for Chinese categories
        """
        if category in ['h', 'ns', 'lb', 'nt']:
            return 'en'
        elif category in ['ch', 'ts']:
            return 'cn'
        else:
            # Default to 'cn' for any new categories
            return 'cn'

    @staticmethod
    def contains_chinese(text: str) -> bool:
        """
        Check if text contains Chinese characters.

        Args:
            text: Text to check

        Returns:
            True if text contains at least one Chinese character
        """
        # Chinese Unicode ranges: \u4e00-\u9fff (CJK Unified Ideographs)
        chinese_pattern = re.compile(r'[\u4e00-\u9fff]+')
        return bool(chinese_pattern.search(text))

    @staticmethod
    def is_valid_author_name(name: str) -> bool:
        """
        Check if an author name is a valid person name.

        Rejects:
        - Initials only (e.g., "S. A. W.", "L. S.", "D. M.")
        - Generic terms (e.g., "Anonymous", "A brother", "Chinese", "Unknown")
        - Non-person entities (e.g., "Streams in the Desert")

        Args:
            name: Author name to validate

        Returns:
            True if the name appears to be a valid person name
        """
        if not name:
            return False

        name = name.strip()
        if not name:
            return False

        # Skip generic/anonymous terms
        generic_terms = {
            'unknown', 'anonymous', 'a brother', 'a sister',
            'chinese', 'german', 'latin', 'greek', 'french',
            'traditional', 'ancient'
        }
        if name.lower() in generic_terms:
            return False

        # Skip initials-only names (e.g., "S. A. W.", "L. S.", "D. M.", "M. D. F.")
        # Pattern: one or more groups of single letter followed by period, separated by spaces
        initials_pattern = re.compile(r'^([A-Z]\.\s*)+$')
        if initials_pattern.match(name):
            return False

        # Skip names that are mostly initials with just one real word
        # e.g., "F. H. Allen" - has "F. H." initials and only "Allen"
        # But allow "Margaret E. Barber" - has real first and last names
        words = name.split()
        real_words = [w for w in words if not re.match(r'^[A-Z]\.$', w)]
        if len(real_words) < 2 and len(words) > 1:
            # Only one real word among multiple parts - likely initials + surname
            return False

        # Skip non-person entities (titles that suggest it's not a person)
        non_person_indicators = [
            'tape', 'song', 'training', 'hymnal', 'book',
            'streams in the desert', 'lsm ', 'selection of hymns',
            'ssot', 'conference'
        ]
        name_lower = name.lower()
        for indicator in non_person_indicators:
            if indicator in name_lower:
                return False

        # Skip names that start with a year (e.g., "2023 Mid-Atlantic SSOT")
        if re.match(r'^\d{4}\s', name):
            return False

        # Skip names with quotes (e.g., '"K" in Rippon\'s Selection')
        if '"' in name or "'" in name and 'selection' in name_lower:
            return False

        return True

    @staticmethod
    def calculate_transpose(from_key: str, to_key: str) -> Optional[int]:
        """
        Calculate the number of half steps (semitones) between two keys.

        Args:
            from_key: Original key (e.g., 'G Major', 'A♭ Major')
            to_key: Target key (e.g., 'A♭ Major', 'G Major')

        Returns:
            Number of half steps to transpose (positive for up, negative for down)
            Returns None if either key is not recognized
        """
        from_semitone = HymnalCrawler.KEY_TO_SEMITONE.get(from_key)
        to_semitone = HymnalCrawler.KEY_TO_SEMITONE.get(to_key)

        if from_semitone is None or to_semitone is None:
            return None

        # Calculate the transpose (positive = up, negative = down)
        transpose = (to_semitone - from_semitone) % 12

        # Convert to range [-6, 6] for more intuitive representation
        # (e.g., -1 instead of 11 for one half step down)
        if transpose > 6:
            transpose -= 12

        return transpose

    @staticmethod
    def contains_english_hymn_tag(hymn_nums_container, expected_number: str, category: str) -> bool:
        """
        Check if the hymn-nums container contains the expected English hymn tag.
        Tag formats vary by category:
        - 'h' category: E<number> (e.g., E1234)
        - 'ns' category: NS<number> (e.g., NS1234)

        Args:
            hymn_nums_container: BeautifulSoup element (div.hymn-nums)
            expected_number: The hymn number from the URL
            category: The hymn category ('h', 'ns', etc.)

        Returns:
            True if the expected tag is found in the container
        """
        if not hymn_nums_container:
            return False

        # Determine expected tag format based on category
        if category == 'h':
            expected_tag = f"E{expected_number}"
        elif category == 'ns':
            expected_tag = f"NS{expected_number}"
        elif category == 'lb':
            expected_tag = f"LB{expected_number}"
        elif category == 'nt':
            expected_tag = f"NT{expected_number}"              
        else:
            # Unknown category format, skip validation
            return True

        # Search for the tag in all text content and links within hymn-nums
        container_text = hymn_nums_container.get_text()

        # Check if the expected tag exists in the container text
        tag_pattern = re.compile(r'\b' + re.escape(expected_tag) + r'\b')
        return bool(tag_pattern.search(container_text))

    def has_manual_edit(self, category: str, number: str) -> bool:
        """
        Check if a manual edit exists for a specific hymn.

        Args:
            category: Category code (e.g., 'h', 'ts', 'ch')
            number: Hymn number

        Returns:
            True if JSON manual file exists
        """
        base_filename = f"{category}_{number}"
        json_path = os.path.join(self.manual_dir, f"{base_filename}.json")

        return os.path.exists(json_path)

    def fetch_hymn(self, url: str, fetch_related: bool = False, output_dir: Optional[str] = None) -> Optional[Dict]:
        """
        Fetch a single hymn page and extract its content.

        Args:
            url: Full URL to the hymn page
            fetch_related: If True, also fetch and validate related hymns (related hymns are fetched with fetch_related=False to prevent recursion)
            output_dir: Optional directory to save fetched hymns immediately

        Returns:
            Dictionary containing hymn data or None if failed
        """
        # Extract identifiers from URL
        url_parts = url.rstrip('/').split('/')
        if len(url_parts) >= 5:
            language = url_parts[-4]
            category = url_parts[-2]
            number = url_parts[-1]
            hymn_key = f"{language}_{category}_{number}"

            # Check if already fetched
            if hymn_key in self.fetched_hymns:
                logger.debug(f"Already fetched {hymn_key}, returning cached version")
                return self.fetched_hymns[hymn_key]
        else:
            hymn_key = None

        try:
            response = self.session.get(url, timeout=10)
            response.raise_for_status()
            hymn_data = self.parse_hymn_page(response.text, url, fetch_related=fetch_related, output_dir=output_dir)

            # Cache the result
            if hymn_key and hymn_data:
                self.fetched_hymns[hymn_key] = hymn_data

            return hymn_data
        except requests.RequestException as e:
            logger.error(f"Error fetching {url}: {e}")
            return None

    def parse_hymn_page(self, html: str, url: str, fetch_related: bool = False, output_dir: Optional[str] = None) -> Optional[Dict]:
        """
        Parse HTML content to extract hymn data.

        Args:
            html: HTML content of the page
            url: URL of the page
            fetch_related: If True, also fetch and validate related hymns
            output_dir: Optional directory to save fetched related hymns immediately

        Returns:
            Dictionary with hymn data, or None if validation fails
        """
        soup = BeautifulSoup(html, 'html.parser')

        # Extract language, category, and number from URL
        # URL format: https://www.hymnal.net/{language}/hymn/{category}/{number}
        # Split gives: ['https:', '', 'www.hymnal.net', 'en', 'hymn', 'h', '1']
        url_parts = url.rstrip('/').split('/')
        language = url_parts[-4] if len(url_parts) >= 5 else None
        category = url_parts[-2] if len(url_parts) >= 3 else None
        hymn_number = url_parts[-1] if len(url_parts) >= 2 else None

        # Extract title first to check for Chinese
        title = ""
        title_elem = soup.find('h2') or soup.find('h1')
        if title_elem:
            title = title_elem.get_text(strip=True)

        # Get content from line divs or fallback areas
        content_text = ""
        line_divs = soup.find_all('div', class_='line')
        if line_divs:
            content_text = ' '.join(div.get_text() for div in line_divs)
        else:
            # Check fallback content areas
            fallback = soup.find('div', class_='chord-container') or \
                      soup.find('div', class_='hymn-content') or \
                      soup.find('div', id='hymn-content') or \
                      soup.find('div', class_='lyrics')
            if fallback:
                content_text = fallback.get_text()

        # Apply validation based on language and category
        if category in ['h', 'ns', 'lb', 'nt']:
            # For English hymns in 'h' and 'ns' categories, check for English hymn tag
            hymn_nums_container = soup.find('div', class_='hymn-nums')
            if not self.contains_english_hymn_tag(hymn_nums_container, hymn_number, category):
                expected_tag = f"{category.upper()}{hymn_number}"
                logger.warning(f"Skipping {url} - hymn-nums container does not contain expected tag {expected_tag}")
                return None
        elif category in ['ch', 'ts']:
            # For Chinese hymns, check if title or content has Chinese
            if not self.contains_chinese(title + content_text):
                logger.warning(f"Skipping {url} - page does not contain Chinese characters")
                return None

        # Extract lines with chord structure
        # Look for verse divs first, then chord-container inside
        lines = []
        verses = []
        raw_sections = []

        # Find all verse divs
        verse_divs = soup.find_all('div', class_='verse')

        for verse_div in verse_divs:
            verse_lines = []
            verse_metadata = {}

            # Extract verse type (verse or chorus)
            verse_type = verse_div.get('data-type', 'verse')
            verse_metadata['type'] = verse_type

            # Extract verse number (only for verses, not chorus)
            verse_num_div = verse_div.find('div', class_='verse-num')
            if verse_num_div:
                verse_num_span = verse_num_div.find('span')
                if verse_num_span:
                    verse_number = verse_num_span.get_text(strip=True)
                    verse_metadata['number'] = verse_number

            # Find chord-container inside this verse
            chord_container = verse_div.find('div', class_='chord-container')
            if not chord_container:
                continue

            # Check if there are line divs inside chord-container
            line_divs = chord_container.find_all('div', class_='line')

            if line_divs:
                # Option 1: Lines with chords
                for line_div in line_divs:
                    line_segments = []

                    # Process each child element in the line
                    for child in line_div.children:
                        if isinstance(child, str):
                            # Plain text node (lyrics without chord)
                            text = child.strip()
                            if text:
                                line_segments.append({
                                    'chord': '',
                                    'text': text
                                })
                        elif child.name == 'div' and 'chord-text' in child.get('class', []):
                            # Chord-text div: extract chord and text
                            chord_span = child.find('span', class_='chord')
                            chord = chord_span.get_text(strip=True) if chord_span else ''

                            # Get text content excluding the chord span
                            text_content = child.get_text(strip=True)
                            if chord_span:
                                chord_text = chord_span.get_text(strip=True)
                                # Remove chord text from beginning
                                if text_content.startswith(chord_text):
                                    text_content = text_content[len(chord_text):].strip()

                            if chord or text_content:
                                line_segments.append({
                                    'chord': chord,
                                    'text': text_content
                                })

                    if line_segments:
                        # Wrap line segments in object to avoid nested arrays (Firestore compatibility)
                        line_obj = {'segments': line_segments}
                        lines.append(line_obj)
                        verse_lines.append(line_obj)
                        # Also store as raw text for backward compatibility
                        line_text = ''.join(seg['text'] for seg in line_segments)
                        if line_text:
                            raw_sections.append(line_text)
            else:
                # Option 2: Pure text separated by <br> tags
                # Replace <br> tags with newlines
                for br in chord_container.find_all('br'):
                    br.replace_with('\n')

                content = chord_container.get_text(strip=False)
                if content:
                    # Split by newlines to get individual lines
                    text_lines = [line.strip() for line in content.split('\n') if line.strip()]

                    for text_line in text_lines:
                        # Wrap segments in object to avoid nested arrays (Firestore compatibility)
                        line_obj = {'segments': [{
                            'chord': '',
                            'text': text_line
                        }]}
                        lines.append(line_obj)
                        verse_lines.append(line_obj)

                    # Store for raw_sections
                    if text_lines:
                        raw_sections.extend(text_lines)

            # Add this verse to verses array if it has lines
            if verse_lines:
                verse_obj = {'lines': verse_lines}
                # Add metadata if available
                if verse_metadata:
                    verse_obj.update(verse_metadata)
                verses.append(verse_obj)

        # Fallback: if no verse divs found, try old parsing method
        if not lines:
            # Look for line divs at top level (old structure)
            line_divs = soup.find_all('div', class_='line')

            for line_div in line_divs:
                line_segments = []

                # Process each child element in the line
                for child in line_div.children:
                    if isinstance(child, str):
                        # Plain text node (lyrics without chord)
                        text = child.strip()
                        if text:
                            line_segments.append({
                                'chord': '',
                                'text': text
                            })
                    elif child.name == 'div' and 'chord-text' in child.get('class', []):
                        # Chord-text div: extract chord and text
                        chord_span = child.find('span', class_='chord')
                        chord = chord_span.get_text(strip=True) if chord_span else ''

                        # Get text content excluding the chord span
                        text_content = child.get_text(strip=True)
                        if chord_span:
                            chord_text = chord_span.get_text(strip=True)
                            # Remove chord text from beginning
                            if text_content.startswith(chord_text):
                                text_content = text_content[len(chord_text):].strip()

                        if chord or text_content:
                            line_segments.append({
                                'chord': chord,
                                'text': text_content
                            })

                if line_segments:
                    # Wrap line segments in object to avoid nested arrays (Firestore compatibility)
                    lines.append({'segments': line_segments})
                    # Also store as raw text for backward compatibility
                    line_text = ''.join(seg['text'] for seg in line_segments)
                    if line_text:
                        raw_sections.append(line_text)

            # If still no content, try alternative selectors
            if not lines:
                content_area = soup.find('div', class_='hymn-content') or \
                              soup.find('div', id='hymn-content') or \
                              soup.find('div', class_='lyrics')

                if content_area:
                    content = content_area.get_text(separator='\n', strip=True)
                    raw_sections.append(content)
                    for text_line in content.split('\n'):
                        if text_line.strip():
                            # Wrap segments in object to avoid nested arrays (Firestore compatibility)
                            lines.append({'segments': [{
                                'chord': '',
                                'text': text_line.strip()
                            }]})

        # Extract metadata
        metadata = {}

        # Try to find category, composer, key, etc.
        meta_section = soup.find('div', class_='details') or soup.find('div', class_='metadata')
        if meta_section:
            for row in meta_section.find_all(['p', 'div', 'li']):
                text = row.get_text(strip=True)
                if ':' in text:
                    key, value = text.split(':', 1)
                    metadata[key.strip()] = value.strip()

        # Extract lyrics author information from row structure (only for English hymns)
        # Chinese uses different header "歌词：" instead of "Lyrics:"
        if language == 'en':
            # Look for rows with label "Lyrics:"
            lyrics_rows = soup.find_all('div', class_='row')
            for row in lyrics_rows:
                label = row.find('label')
                if label and 'Lyrics:' in label.get_text():
                    # Find the content div (col-xs-7 col-sm-8)
                    content_div = row.find('div', class_=['col-xs-7', 'col-sm-8'])
                    if content_div:
                        full_text = content_div.get_text()

                        # Check if "Translated by" is present
                        if 'Translated by' in full_text:
                            # Find all author links
                            author_links = content_div.find_all('a', href=lambda h: h and '/search/all/author/' in h)
                            # The translator should be the link after "Translated by"
                            for link in author_links:
                                # Check if this link comes after "Translated by" in the text
                                link_text = link.get_text(strip=True)
                                if link_text and link_text != 'Unknown' and self.is_valid_author_name(link_text):
                                    # Get the full text up to this link
                                    link_position = full_text.find(link_text)
                                    text_before_link = full_text[:link_position]
                                    if 'Translated by' in text_before_link:
                                        metadata['lyrics'] = link_text
                                        break
                        else:
                            # No translation, just get the first author link
                            author_link = content_div.find('a', href=lambda h: h and '/search/all/author/' in h)
                            if author_link:
                                author_name = author_link.get_text(strip=True)
                                # Only add if name is valid (not "Unknown", not initials-only, etc.)
                                if author_name and self.is_valid_author_name(author_name):
                                    metadata['lyrics'] = author_name
                        break

        # Extract category from links (format: /<lang>/search/all/category/...)
        # Exclude links within div.list-group
        category_links = soup.find_all('a', href=True)
        for link in category_links:
            href = link.get('href', '')
            if '/en/search/all/category/' in href or '/cn/search/all/category/' in href:
                # Skip links inside div.list-group
                if link.find_parent('div', class_='list-group'):
                    continue
                # Extract category value from the URL
                category_value = link.get_text(strip=True)
                if category_value:
                    metadata['category'] = category_value
                    break

        # Extract time from links (format: /<lang>/search/all/time/...)
        for link in category_links:
            href = link.get('href', '')
            if '/en/search/all/time/' in href or '/cn/search/all/time/' in href:
                # Skip links inside div.list-group
                if link.find_parent('div', class_='list-group'):
                    continue
                # Extract time value from the URL
                time_value = link.get_text(strip=True)
                if time_value:
                    metadata['time'] = time_value
                    break

        # Extract hymn_code from links (format: /<lang>/search/all/hymncode/...)
        for link in category_links:
            href = link.get('href', '')
            if '/en/search/all/hymncode/' in href or '/cn/search/all/hymncode/' in href:
                # Skip links inside div.list-group
                if link.find_parent('div', class_='list-group'):
                    continue
                # Extract hymn_code value from the URL
                hymncode_value = link.get_text(strip=True)
                if hymncode_value:
                    metadata['hymn_code'] = hymncode_value
                    break

        # Extract MIDI tune URL from links (format: /midi/tunes/)
        for link in category_links:
            href = link.get('href', '')
            if '/midi/tunes/' in href:
                # Get the full URL
                midi_url = href if href.startswith('http') else f"{self.base_url}{href}"
                metadata['midi_tune_url'] = midi_url
                break

        # Extract guitar leadsheet URL from div.leadsheet.guitar
        guitar_leadsheet_div = soup.find('div', class_=lambda c: c and 'leadsheet' in c and 'guitar' in c)
        if guitar_leadsheet_div:
            # Try to find URL in span.svg (text content)
            svg_span = guitar_leadsheet_div.find('span', class_='svg')
            if svg_span:
                leadsheet_src = svg_span.get_text(strip=True)
                if leadsheet_src:
                    leadsheet_url = leadsheet_src if leadsheet_src.startswith('http') else f"{self.base_url}{leadsheet_src}"
                    metadata['guitar_leadsheet_url'] = leadsheet_url
            else:
                # Fallback: try img tag with src attribute
                img_tag = guitar_leadsheet_div.find('img', src=True)
                if img_tag:
                    leadsheet_src = img_tag.get('src', '')
                    if leadsheet_src:
                        leadsheet_url = leadsheet_src if leadsheet_src.startswith('http') else f"{self.base_url}{leadsheet_src}"
                        metadata['guitar_leadsheet_url'] = leadsheet_url

        # Extract key signatures and calculate capo position
        # keysig = current key, fromkeysig = original key
        keysig_span = soup.find('span', id='keysig')
        fromkeysig_span = soup.find('span', id='fromkeysig')

        if keysig_span and fromkeysig_span:
            current_key = keysig_span.get_text(strip=True)
            original_key = fromkeysig_span.get_text(strip=True)

            if current_key:
                metadata['current_key'] = current_key
            if original_key:
                metadata['original_key'] = original_key

            # Calculate capo position if both keys are present
            if current_key and original_key:
                capo = self.calculate_transpose(original_key, current_key)
                if capo is not None:
                    metadata['capo'] = capo

        # Extract and optionally fetch related hymns from links within div.hymn-nums container
        # Only search within div.hymn-nums, excluding div.list-group
        related_hymns = []
        hymn_nums_container = soup.find('div', class_='hymn-nums')
        if hymn_nums_container:
            hymn_link_pattern = re.compile(r'^/(en|cn)/hymn/([a-z]+)/(\d+)$')
            hymn_links = hymn_nums_container.find_all('a', href=True)

            for link in hymn_links:
                href = link.get('href', '')
                match = hymn_link_pattern.match(href)
                if match:
                    # Skip links inside div.list-group
                    if link.find_parent('div', class_='list-group'):
                        continue

                    # Extract category and number from URL (language is determined from category)
                    category = match.group(2)
                    number = match.group(3)

                    # Skip unsupported categories
                    if category not in self.SUPPORTED_CATEGORIES:
                        continue

                    # Determine language from category
                    lang = self.get_language_from_category(category)

                    # Create full URL for the related hymn using determined language
                    related_url = f"{self.base_url}/{lang}/hymn/{category}/{number}"
                    # Get the link text which might contain the title
                    link_text = link.get_text(strip=True)

                    # If fetch_related is enabled, fetch and validate the related hymn
                    if fetch_related:
                        logger.info(f"Fetching related hymn: {lang}/{category}/{number}")

                        # Fetch the related hymn page without validation
                        # We need to fetch and parse the HTML directly to bypass validation
                        try:
                            related_response = self.session.get(related_url, timeout=10)
                            related_response.raise_for_status()

                            # Parse the full hymn data (fetch_related=False to prevent recursion)
                            related_hymn_data = self.parse_hymn_page(
                                related_response.text,
                                related_url,
                                fetch_related=False,
                                output_dir=output_dir
                            )

                            # Only save and add to related list if parsing succeeded
                            if related_hymn_data:
                                # Save the related hymn if output_dir is provided
                                if output_dir:
                                    self.save_hymns([related_hymn_data], output_dir=output_dir)

                                # Add to related hymns list
                                related_hymns.append({
                                    'url': related_url,
                                    'language': lang,
                                    'category': category,
                                    'number': number,
                                    'title': link_text if link_text else related_hymn_data['title']
                                })
                            else:
                                logger.warning(f"Skipping related hymn {category}/{number} - parsing/validation failed")

                            # Add delay to be respectful to server
                            time.sleep(1)
                        except requests.RequestException as e:
                            logger.error(f"Failed to fetch related hymn {lang}/{category}/{number}: {e}")
                    else:
                        # Just store the link without fetching
                        related_hymns.append({
                            'url': related_url,
                            'language': lang,
                            'category': category,
                            'number': number,
                            'title': link_text if link_text else None
                        })

        if related_hymns:
            metadata['related'] = related_hymns

        # If no verses were found but we have lines, create a single verse with all lines
        if not verses and lines:
            verses = [{'lines': lines}]

        return {
            'url': url,
            'title': title,
            'verses': verses,
            'metadata': metadata,
            'raw_sections': raw_sections
        }

    def crawl_hymn_range(self, category: str, start: int, end: int, output_dir: Optional[str] = None, fetch_related: bool = False) -> List[Dict]:
        """
        Crawl a range of hymns from a specific category.

        Args:
            category: Category code (e.g., 'ts', 'h', 'ns', 'ch')
            start: Starting hymn number
            end: Ending hymn number
            output_dir: Optional directory to save hymns incrementally. If provided, hymns are saved
                       immediately after fetching. If None, hymns are only stored in memory.
            fetch_related: If True, also fetch and validate related hymns. Defaults to False.

        Returns:
            List of hymn dictionaries

        Raises:
            ValueError: If category is not supported
        """
        # Validate category
        if category not in self.SUPPORTED_CATEGORIES:
            supported = ', '.join(f"'{k}' ({v})" for k, v in self.SUPPORTED_CATEGORIES.items())
            raise ValueError(
                f"Unsupported category: '{category}'. "
                f"Supported categories are: {supported}"
            )

        # Determine language from category
        language = self.get_language_from_category(category)

        # Create output directory if incremental saving is enabled
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        hymns = []

        for num in range(start, end + 1):
            url = f"{self.base_url}/{language}/hymn/{category}/{num}"
            logger.info(f"Fetching hymn {num}...")

            hymn_data = self.fetch_hymn(url, fetch_related=fetch_related, output_dir=output_dir)
            if hymn_data:
                hymns.append(hymn_data)

                # Save immediately if output_dir is provided (only the main hymn, related are saved in fetch_hymn)
                if output_dir and not fetch_related:
                    self.save_hymns([hymn_data], output_dir=output_dir)

            # Be respectful to the server
            time.sleep(0.5)

        return hymns

    def save_hymns(self, hymns: List[Dict], output_dir: str = "hymns"):
        """
        Save hymns to files using <category>_<number> naming convention.

        Args:
            hymns: List of hymn dictionaries
            output_dir: Directory to save files
        """
        os.makedirs(output_dir, exist_ok=True)

        # Save individual files for each hymn
        for hymn in hymns:
            # Extract category and number from URL
            # URL format: https://www.hymnal.net/{language}/hymn/{category}/{number}
            url_parts = hymn['url'].rstrip('/').split('/')
            category = url_parts[-2] if len(url_parts) >= 2 else 'unknown'
            number = url_parts[-1] if len(url_parts) >= 1 else '0'

            # Skip if manual edit exists
            if self.has_manual_edit(category, number):
                logger.info(f"Skipping {category}_{number} - manual edit exists in {self.manual_dir}")
                continue

            # Create filename with category and number
            base_filename = f"{category}_{number}"

            # Save as JSON
            json_path = os.path.join(output_dir, f'{base_filename}.json')
            with open(json_path, 'w', encoding='utf-8') as f:
                json.dump(hymn, f, ensure_ascii=False, indent=2)
            logger.info(f"Saved {json_path}")

        logger.info(f"Saved {len(hymns)} hymn(s) to {output_dir}")
