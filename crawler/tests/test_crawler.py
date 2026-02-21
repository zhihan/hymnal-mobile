"""
Unit tests for HymnalCrawler class.
"""

import pytest
import json
import os
from unittest.mock import Mock, patch, MagicMock
from hymnal_crawler import HymnalCrawler


class TestHymnalCrawlerInit:
    """Test HymnalCrawler initialization."""

    def test_init_default(self):
        """Test default initialization."""
        crawler = HymnalCrawler()
        assert crawler.base_url == "https://www.hymnal.net"
        assert crawler.session is not None
        assert 'User-Agent' in crawler.session.headers

    def test_init_custom_base_url(self):
        """Test initialization with custom base URL."""
        custom_url = "https://custom.hymnal.net"
        crawler = HymnalCrawler(base_url=custom_url)
        assert crawler.base_url == custom_url

    def test_supported_categories(self):
        """Test SUPPORTED_CATEGORIES constant."""
        crawler = HymnalCrawler()
        assert 'h' in crawler.SUPPORTED_CATEGORIES
        assert 'ns' in crawler.SUPPORTED_CATEGORIES
        assert 'ch' in crawler.SUPPORTED_CATEGORIES
        assert 'ts' in crawler.SUPPORTED_CATEGORIES
        assert 'lb' in crawler.SUPPORTED_CATEGORIES
        assert 'nt' in crawler.SUPPORTED_CATEGORIES
        assert len(crawler.SUPPORTED_CATEGORIES) == 6


class TestIsValidAuthorName:
    """Test is_valid_author_name static method."""

    def test_valid_full_names(self):
        """Test that valid full names are accepted."""
        assert HymnalCrawler.is_valid_author_name("Witness Lee") is True
        assert HymnalCrawler.is_valid_author_name("Charles Wesley") is True
        assert HymnalCrawler.is_valid_author_name("Margaret E. Barber") is True
        assert HymnalCrawler.is_valid_author_name("Fanny Jane Crosby") is True
        assert HymnalCrawler.is_valid_author_name("Albert Benjamin Simpson") is True

    def test_initials_only_rejected(self):
        """Test that initials-only names are rejected."""
        assert HymnalCrawler.is_valid_author_name("S. A. W.") is False
        assert HymnalCrawler.is_valid_author_name("L. S.") is False
        assert HymnalCrawler.is_valid_author_name("D. M.") is False
        assert HymnalCrawler.is_valid_author_name("R. H.") is False
        assert HymnalCrawler.is_valid_author_name("M. D. F.") is False

    def test_initials_with_surname_rejected(self):
        """Test that names with initials and only one real word are rejected."""
        assert HymnalCrawler.is_valid_author_name("F. H. Allen") is False
        assert HymnalCrawler.is_valid_author_name("S. T. P.") is False

    def test_generic_terms_rejected(self):
        """Test that generic terms are rejected."""
        assert HymnalCrawler.is_valid_author_name("Anonymous") is False
        assert HymnalCrawler.is_valid_author_name("A brother") is False
        assert HymnalCrawler.is_valid_author_name("A sister") is False
        assert HymnalCrawler.is_valid_author_name("Chinese") is False
        assert HymnalCrawler.is_valid_author_name("Unknown") is False
        assert HymnalCrawler.is_valid_author_name("Traditional") is False

    def test_non_person_entities_rejected(self):
        """Test that non-person entities are rejected."""
        assert HymnalCrawler.is_valid_author_name("Streams in the Desert") is False
        assert HymnalCrawler.is_valid_author_name("LSM Corinthians Training Song Tape") is False

    def test_empty_or_none_rejected(self):
        """Test that empty strings are rejected."""
        assert HymnalCrawler.is_valid_author_name("") is False
        assert HymnalCrawler.is_valid_author_name("   ") is False


class TestParseHymnPage:
    """Test parse_hymn_page method."""

    def test_parse_with_chord_text_divs(self):
        """Test parsing HTML with chord-text divs within line containers."""
        html = """
        <html>
            <head><title>Test</title></head>
            <body>
                <h2>测试诗歌</h2>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>第一行</div>
                </div>
                <div class="line">
                    <div class="chord-text"><span class="chord">G</span>第二行</div>
                </div>
                <div class="details">
                    <p>Category: Traditional</p>
                    <p>Key: C</p>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://example.com")

        assert result['title'] == "测试诗歌"
        assert result['url'] == "https://example.com"
        assert 'lines' not in result  # No root-level lines
        assert 'verses' in result
        assert len(result['verses']) == 1  # Single verse fallback
        assert len(result['verses'][0]['lines']) == 2
        assert result['verses'][0]['lines'][0]['segments'][0]['chord'] == "C"
        assert result['verses'][0]['lines'][0]['segments'][0]['text'] == "第一行"
        assert result['verses'][0]['lines'][1]['segments'][0]['chord'] == "G"
        assert result['verses'][0]['lines'][1]['segments'][0]['text'] == "第二行"
        assert result['metadata']['Category'] == "Traditional"
        assert result['metadata']['Key'] == "C"

    def test_parse_with_h1_title(self):
        """Test parsing HTML with h1 instead of h2 for title."""
        html = """
        <html>
            <body>
                <h1>标题测试</h1>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>歌词</div>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://example.com")

        assert result['title'] == "标题测试"

    def test_parse_with_fallback_content(self):
        """Test parsing with fallback content area when no line divs."""
        html = """
        <html>
            <body>
                <h2>后备测试</h2>
                <div class="hymn-content">歌词第一行
歌词第二行</div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://example.com")

        assert result['title'] == "后备测试"
        assert 'lines' not in result
        assert len(result['verses']) == 1
        assert len(result['verses'][0]['lines']) == 2
        assert result['verses'][0]['lines'][0]['segments'][0]['chord'] == ""
        assert result['verses'][0]['lines'][0]['segments'][0]['text'] == "歌词第一行"
        assert result['verses'][0]['lines'][1]['segments'][0]['chord'] == ""
        assert result['verses'][0]['lines'][1]['segments'][0]['text'] == "歌词第二行"

    def test_parse_with_no_title(self):
        """Test parsing HTML with no title."""
        html = """
        <html>
            <body>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>歌词</div>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://example.com")

        assert result['title'] == ""

    def test_parse_with_no_content(self):
        """Test parsing HTML with no hymn content but Chinese title."""
        html = """
        <html>
            <body>
                <h2>空的诗歌</h2>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://example.com")

        assert result['title'] == "空的诗歌"
        assert len(result['verses']) == 0
        assert len(result['raw_sections']) == 0

    def test_parse_metadata_with_div_metadata_class(self):
        """Test parsing metadata from div with metadata class."""
        html = """
        <html>
            <body>
                <h2>元数据测试</h2>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>歌词</div>
                </div>
                <div class="metadata">
                    <div>Composer: John Doe</div>
                    <div>Year: 2020</div>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://example.com")

        assert result['metadata']['Composer'] == "John Doe"
        assert result['metadata']['Year'] == "2020"

    def test_parse_with_verses(self):
        """Test parsing HTML with verse divs."""
        html = """
        <html>
            <body>
                <h2>诗歌测试</h2>
                <div class="verse">
                    <div class="chord-container">
                        <div class="line">
                            <div class="chord-text"><span class="chord">C</span>第一节</div>
                        </div>
                    </div>
                </div>
                <div class="verse">
                    <div class="chord-container">
                        <div class="line">
                            <div class="chord-text"><span class="chord">G</span>第二节</div>
                        </div>
                    </div>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://example.com")

        assert len(result['verses']) == 2
        assert len(result['verses'][0]['lines']) == 1
        assert len(result['verses'][1]['lines']) == 1
        assert result['verses'][0]['lines'][0]['segments'][0]['chord'] == "C"
        assert result['verses'][1]['lines'][0]['segments'][0]['chord'] == "G"

    def test_parse_lyrics_author_simple(self):
        """Test parsing lyrics author with simple single author (English hymn)."""
        html = """
        <html>
            <body>
                <h2>Test Hymn</h2>
                <div class="hymn-nums">
                    <a href="/en/hymn/h/12">E12</a>
                </div>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>Lyrics</div>
                </div>
                <div class="row">
                    <label class="col-xs-5 col-sm-4">Lyrics:</label>
                    <div class="col-xs-7 col-sm-8 no-padding">
                        <a href="/en/search/all/author/Witness+Lee?t=h&amp;n=12">Witness Lee</a>&nbsp;<wbr>(1905-1997) <a class="label label-info" href="https://www.witnesslee.org" target="_blank" rel="noopener noreferrer">bio</a>
                    </div>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://www.hymnal.net/en/hymn/h/12")

        assert 'lyrics' in result['metadata']
        assert result['metadata']['lyrics'] == "Witness Lee"

    def test_parse_lyrics_author_translated(self):
        """Test parsing lyrics author with translation (should use translator)."""
        html = """
        <html>
            <body>
                <h2>Test Hymn</h2>
                <div class="hymn-nums">
                    <a href="/en/hymn/h/33">E33</a>
                </div>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>Lyrics</div>
                </div>
                <div class="row">
                    <label class="col-xs-5 col-sm-4">Lyrics:</label>
                    <div class="col-xs-7 col-sm-8 no-padding">
                        <a href="/en/search/all/author/Chinese?t=h&amp;n=33">Chinese</a>; Translated by <a href="/en/search/all/author/Francis+P.+Jones?t=h&amp;n=33">Francis P. Jones</a>
                    </div>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://www.hymnal.net/en/hymn/h/33")

        assert 'lyrics' in result['metadata']
        assert result['metadata']['lyrics'] == "Francis P. Jones"

    def test_parse_lyrics_author_unknown(self):
        """Test parsing lyrics author when author is Unknown (should be skipped)."""
        html = """
        <html>
            <body>
                <h2>Test Hymn</h2>
                <div class="hymn-nums">
                    <a href="/en/hymn/h/12">E12</a>
                </div>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>Lyrics</div>
                </div>
                <div class="row">
                    <label class="col-xs-5 col-sm-4">Lyrics:</label>
                    <div class="col-xs-7 col-sm-8 no-padding">
                        <a href="/en/search/all/author/Unknown?t=h&amp;n=12">Unknown</a>
                    </div>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://www.hymnal.net/en/hymn/h/12")

        assert 'lyrics' not in result['metadata']

    def test_parse_lyrics_author_initials_skipped(self):
        """Test parsing lyrics author when author is initials only (should be skipped)."""
        html = """
        <html>
            <body>
                <h2>Test Hymn</h2>
                <div class="hymn-nums">
                    <a href="/en/hymn/h/12">E12</a>
                </div>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>Lyrics</div>
                </div>
                <div class="row">
                    <label class="col-xs-5 col-sm-4">Lyrics:</label>
                    <div class="col-xs-7 col-sm-8 no-padding">
                        <a href="/en/search/all/author/S.+A.+W.?t=h&amp;n=12">S. A. W.</a>
                    </div>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://www.hymnal.net/en/hymn/h/12")

        # Should not extract lyrics for initials-only authors
        assert 'lyrics' not in result['metadata']

    def test_parse_lyrics_author_no_link(self):
        """Test parsing lyrics author without link (should be skipped)."""
        html = """
        <html>
            <body>
                <h2>Test Hymn</h2>
                <div class="hymn-nums">
                    <a href="/en/hymn/h/12">E12</a>
                </div>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>Lyrics</div>
                </div>
                <div class="row">
                    <label class="col-xs-5 col-sm-4">Lyrics:</label>
                    <div class="col-xs-7 col-sm-8 no-padding">
                        Adapted
                    </div>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://www.hymnal.net/en/hymn/h/12")

        assert 'lyrics' not in result['metadata']

    def test_parse_lyrics_author_no_lyrics_row(self):
        """Test parsing when no lyrics row exists (should not error)."""
        html = """
        <html>
            <body>
                <h2>Test Hymn</h2>
                <div class="hymn-nums">
                    <a href="/en/hymn/h/12">E12</a>
                </div>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>Lyrics</div>
                </div>
                <div class="details">
                    <p>Category: Traditional</p>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://www.hymnal.net/en/hymn/h/12")

        assert 'lyrics' not in result['metadata']
        assert 'Category' in result['metadata']

    def test_parse_lyrics_author_chinese_hymn_skipped(self):
        """Test that Chinese hymns do not extract lyrics author."""
        html = """
        <html>
            <body>
                <h2>测试诗歌</h2>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>歌词</div>
                </div>
                <div class="row">
                    <label class="col-xs-5 col-sm-4">Lyrics:</label>
                    <div class="col-xs-7 col-sm-8 no-padding">
                        <a href="/cn/search/all/author/Witness+Lee?t=ts&amp;n=12">Witness Lee</a>
                    </div>
                </div>
            </body>
        </html>
        """
        crawler = HymnalCrawler()
        result = crawler.parse_hymn_page(html, "https://www.hymnal.net/cn/hymn/ts/12")

        # Should not extract lyrics for Chinese hymns
        assert 'lyrics' not in result['metadata']


class TestFetchHymn:
    """Test fetch_hymn method."""

    @patch('hymnal_crawler.crawler.requests.Session.get')
    def test_fetch_hymn_success(self, mock_get):
        """Test successful hymn fetch."""
        mock_response = Mock()
        mock_response.text = """
        <html>
            <body>
                <h2>测试诗歌</h2>
                <div class="line">
                    <div class="chord-text"><span class="chord">C</span>歌词</div>
                </div>
            </body>
        </html>
        """
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        crawler = HymnalCrawler()
        result = crawler.fetch_hymn("https://www.hymnal.net/cn/hymn/ts/846")

        assert result is not None
        assert result['title'] == "测试诗歌"
        mock_get.assert_called_once_with("https://www.hymnal.net/cn/hymn/ts/846", timeout=10)

    @patch('hymnal_crawler.crawler.requests.Session.get')
    def test_fetch_hymn_request_exception(self, mock_get):
        """Test fetch_hymn handles request exceptions."""
        import requests
        mock_get.side_effect = requests.RequestException("Network error")

        crawler = HymnalCrawler()
        result = crawler.fetch_hymn("https://www.hymnal.net/cn/hymn/ts/846")

        assert result is None

    @patch('hymnal_crawler.crawler.requests.Session.get')
    def test_fetch_hymn_http_error(self, mock_get):
        """Test fetch_hymn handles HTTP errors."""
        import requests
        mock_response = Mock()
        mock_response.raise_for_status.side_effect = requests.RequestException("404 Not Found")
        mock_get.return_value = mock_response

        crawler = HymnalCrawler()
        result = crawler.fetch_hymn("https://www.hymnal.net/cn/hymn/ts/999999")

        assert result is None


class TestCrawlHymnRange:
    """Test crawl_hymn_range method."""

    @patch('hymnal_crawler.crawler.time.sleep')
    @patch.object(HymnalCrawler, 'fetch_hymn')
    def test_crawl_hymn_range_success(self, mock_fetch, mock_sleep):
        """Test crawling a range of hymns."""
        mock_fetch.side_effect = [
            {'url': 'url1', 'title': 'Hymn 1', 'verses': []},
            {'url': 'url2', 'title': 'Hymn 2', 'verses': []},
            {'url': 'url3', 'title': 'Hymn 3', 'verses': []}
        ]

        crawler = HymnalCrawler()
        result = crawler.crawl_hymn_range('ts', 1, 3)

        assert len(result) == 3
        assert result[0]['title'] == 'Hymn 1'
        assert result[2]['title'] == 'Hymn 3'
        assert mock_fetch.call_count == 3
        assert mock_sleep.call_count == 3
        mock_sleep.assert_called_with(0.5)

    @patch('hymnal_crawler.crawler.time.sleep')
    @patch.object(HymnalCrawler, 'fetch_hymn')
    def test_crawl_hymn_range_with_failures(self, mock_fetch, mock_sleep):
        """Test crawling range with some failures."""
        mock_fetch.side_effect = [
            {'url': 'url1', 'title': 'Hymn 1', 'verses': []},
            None,  # Failed fetch
            {'url': 'url3', 'title': 'Hymn 3', 'verses': []}
        ]

        crawler = HymnalCrawler()
        result = crawler.crawl_hymn_range('ts', 1, 3)

        assert len(result) == 2
        assert result[0]['title'] == 'Hymn 1'
        assert result[1]['title'] == 'Hymn 3'

    def test_crawl_hymn_range_unsupported_category(self):
        """Test crawl_hymn_range with unsupported category."""
        crawler = HymnalCrawler()

        with pytest.raises(ValueError) as exc_info:
            crawler.crawl_hymn_range('xyz', 1, 10)

        assert "Unsupported category" in str(exc_info.value)
        assert "xyz" in str(exc_info.value)


class TestSaveHymns:
    """Test save_hymns method."""

    def test_save_hymns_creates_directory(self, tmp_path):
        """Test that save_hymns creates output directory."""
        output_dir = tmp_path / "test_hymns"
        hymns = [
            {
                'url': 'https://www.hymnal.net/cn/hymn/ts/1',
                'title': 'Test Hymn',
                'verses': [{'lines': [{'segments': [{'chord': 'C', 'text': 'Line 1'}]}]}],
                'metadata': {'Key': 'C'},
                'raw_sections': []
            }
        ]

        crawler = HymnalCrawler()
        crawler.save_hymns(hymns, output_dir=str(output_dir))

        assert output_dir.exists()

    def test_save_hymns_creates_json(self, tmp_path):
        """Test that save_hymns creates individual JSON files."""
        output_dir = tmp_path / "test_hymns"
        hymns = [
            {
                'url': 'https://www.hymnal.net/cn/hymn/ts/846',
                'title': 'Test Hymn',
                'verses': [{'lines': [{'segments': [{'chord': 'C', 'text': 'Line 1'}]}]}],
                'metadata': {'Key': 'C'},
                'raw_sections': ['Line 1']
            }
        ]

        crawler = HymnalCrawler()
        crawler.save_hymns(hymns, output_dir=str(output_dir))

        json_path = output_dir / "ts_846.json"
        assert json_path.exists()

        with open(json_path, 'r', encoding='utf-8') as f:
            loaded = json.load(f)
            assert loaded['title'] == 'Test Hymn'
            assert loaded['url'] == 'https://www.hymnal.net/cn/hymn/ts/846'
            assert 'verses' in loaded
            assert 'lines' not in loaded  # No root-level lines

    def test_save_hymns_empty_list(self, tmp_path):
        """Test saving empty list of hymns."""
        output_dir = tmp_path / "test_hymns"
        hymns = []

        crawler = HymnalCrawler()
        crawler.save_hymns(hymns, output_dir=str(output_dir))

        # Directory should exist
        assert output_dir.exists()

        # No files should be created
        files = list(output_dir.iterdir())
        assert len(files) == 0

    def test_save_hymns_with_multiple_verses(self, tmp_path):
        """Test saving hymns with multiple verses."""
        output_dir = tmp_path / "test_hymns"
        hymns = [
            {
                'url': 'https://www.hymnal.net/cn/hymn/ts/1',
                'title': 'Multi-Verse Hymn',
                'verses': [
                    {'lines': [{'segments': [{'chord': 'C', 'text': 'Verse 1 Line 1'}]}]},
                    {'lines': [{'segments': [{'chord': 'G', 'text': 'Verse 2 Line 1'}]}]}
                ],
                'metadata': {},
                'raw_sections': []
            }
        ]

        crawler = HymnalCrawler()
        crawler.save_hymns(hymns, output_dir=str(output_dir))

        json_path = output_dir / "ts_1.json"
        assert json_path.exists()

        with open(json_path, 'r', encoding='utf-8') as f:
            loaded = json.load(f)
            assert loaded['title'] == 'Multi-Verse Hymn'
            assert len(loaded['verses']) == 2
