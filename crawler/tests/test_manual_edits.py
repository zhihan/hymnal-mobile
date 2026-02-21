"""
Tests for manual hymn editing functionality.
"""

import os
import json
import pytest
import tempfile
import shutil
from hymnal_crawler import HymnalCrawler


@pytest.fixture
def temp_dirs():
    """Create temporary directories for testing."""
    # Create temporary directories
    hymns_dir = tempfile.mkdtemp(prefix="hymns_")
    manual_dir = tempfile.mkdtemp(prefix="hymns_manual_")

    yield hymns_dir, manual_dir

    # Cleanup
    shutil.rmtree(hymns_dir, ignore_errors=True)
    shutil.rmtree(manual_dir, ignore_errors=True)


@pytest.fixture
def sample_hymn():
    """Create a sample hymn dictionary for testing."""
    return {
        "url": "https://www.hymnal.net/cn/hymn/ts/5",
        "title": "Test Hymn",
        "verses": [
            {
                "type": "verse",
                "number": "1",
                "lines": [
                    {
                        "segments": [
                            {"chord": "G", "text": "Test"},
                            {"chord": "", "text": " lyrics"}
                        ]
                    }
                ]
            }
        ],
        "metadata": {
            "category": "Test Category"
        },
        "raw_sections": []
    }


class TestHasManualEdit:
    """Tests for has_manual_edit() method."""

    def test_has_manual_edit_json_exists(self, temp_dirs):
        """Test detection when JSON file exists."""
        hymns_dir, manual_dir = temp_dirs
        crawler = HymnalCrawler(manual_dir=manual_dir)

        # Create a manual JSON file
        json_path = os.path.join(manual_dir, "ts_5.json")
        with open(json_path, 'w') as f:
            json.dump({"test": "data"}, f)

        assert crawler.has_manual_edit('ts', '5') is True

    def test_has_manual_edit_none_exist(self, temp_dirs):
        """Test detection when file does not exist."""
        hymns_dir, manual_dir = temp_dirs
        crawler = HymnalCrawler(manual_dir=manual_dir)

        assert crawler.has_manual_edit('ts', '5') is False

    def test_has_manual_edit_different_hymn(self, temp_dirs):
        """Test that it only detects the specified hymn."""
        hymns_dir, manual_dir = temp_dirs
        crawler = HymnalCrawler(manual_dir=manual_dir)

        # Create manual file for ts_5
        json_path = os.path.join(manual_dir, "ts_5.json")
        with open(json_path, 'w') as f:
            json.dump({"test": "data"}, f)

        # Check for ts_5 (should exist)
        assert crawler.has_manual_edit('ts', '5') is True

        # Check for ts_6 (should not exist)
        assert crawler.has_manual_edit('ts', '6') is False


class TestSaveHymnsWithManualEdits:
    """Tests for save_hymns() method with manual edits."""

    def test_save_hymns_skips_manual_edits(self, temp_dirs, sample_hymn):
        """Test that save_hymns skips hymns with manual edits."""
        hymns_dir, manual_dir = temp_dirs
        crawler = HymnalCrawler(manual_dir=manual_dir)

        # Create a manual edit
        manual_json_path = os.path.join(manual_dir, "ts_5.json")
        manual_data = {"modified": True, "url": sample_hymn["url"]}
        with open(manual_json_path, 'w') as f:
            json.dump(manual_data, f)

        # Try to save the hymn
        crawler.save_hymns([sample_hymn], output_dir=hymns_dir)

        # Check that output directory does NOT have the file
        output_json_path = os.path.join(hymns_dir, "ts_5.json")
        assert not os.path.exists(output_json_path)

        # Check that manual edit still exists and unchanged
        with open(manual_json_path, 'r') as f:
            saved_data = json.load(f)
        assert saved_data["modified"] is True

    def test_save_hymns_saves_non_manual(self, temp_dirs, sample_hymn):
        """Test that save_hymns saves hymns without manual edits."""
        hymns_dir, manual_dir = temp_dirs
        crawler = HymnalCrawler(manual_dir=manual_dir)

        # No manual edit exists - save should work
        crawler.save_hymns([sample_hymn], output_dir=hymns_dir)

        # Check that output directory has the file
        output_json_path = os.path.join(hymns_dir, "ts_5.json")
        assert os.path.exists(output_json_path)

        # Verify content
        with open(output_json_path, 'r') as f:
            saved_data = json.load(f)
        assert saved_data["title"] == "Test Hymn"

    def test_save_hymns_mixed_manual_and_non_manual(self, temp_dirs, sample_hymn):
        """Test saving multiple hymns with some having manual edits."""
        hymns_dir, manual_dir = temp_dirs
        crawler = HymnalCrawler(manual_dir=manual_dir)

        # Create second hymn
        hymn2 = sample_hymn.copy()
        hymn2["url"] = "https://www.hymnal.net/cn/hymn/ts/6"
        hymn2["title"] = "Test Hymn 2"

        # Create manual edit for ts_5 only
        manual_json_path = os.path.join(manual_dir, "ts_5.json")
        with open(manual_json_path, 'w') as f:
            json.dump({"modified": True}, f)

        # Save both hymns
        crawler.save_hymns([sample_hymn, hymn2], output_dir=hymns_dir)

        # ts_5 should NOT be saved
        assert not os.path.exists(os.path.join(hymns_dir, "ts_5.json"))

        # ts_6 should be saved
        assert os.path.exists(os.path.join(hymns_dir, "ts_6.json"))


class TestCustomManualDirectory:
    """Tests for custom manual directory configuration."""

    def test_custom_manual_dir(self, temp_dirs):
        """Test that custom manual directory works."""
        hymns_dir, _ = temp_dirs
        custom_dir = tempfile.mkdtemp(prefix="custom_manual_")

        try:
            crawler = HymnalCrawler(manual_dir=custom_dir)

            # Create file in custom directory
            json_path = os.path.join(custom_dir, "ts_5.json")
            with open(json_path, 'w') as f:
                json.dump({"test": "data"}, f)

            # Should detect manual edit
            assert crawler.has_manual_edit('ts', '5') is True
        finally:
            shutil.rmtree(custom_dir, ignore_errors=True)

    def test_default_manual_dir(self):
        """Test that default manual directory is 'hymns_manual'."""
        crawler = HymnalCrawler()
        assert crawler.manual_dir == "hymns_manual"


class TestIntegration:
    """Integration tests for the full workflow."""

    def test_full_workflow(self, temp_dirs, sample_hymn):
        """Test the complete workflow: save, manual edit, re-save."""
        hymns_dir, manual_dir = temp_dirs
        crawler = HymnalCrawler(manual_dir=manual_dir)

        # 1. Save hymn normally
        crawler.save_hymns([sample_hymn], output_dir=hymns_dir)
        output_json = os.path.join(hymns_dir, "ts_5.json")
        assert os.path.exists(output_json)

        # 2. Copy to manual directory and modify
        manual_json = os.path.join(manual_dir, "ts_5.json")
        with open(output_json, 'r') as f:
            data = json.load(f)
        data["manually_edited"] = True
        with open(manual_json, 'w') as f:
            json.dump(data, f)

        # 3. Try to save again (should be skipped)
        crawler.save_hymns([sample_hymn], output_dir=hymns_dir)

        # Output file should still have old data (not modified)
        with open(output_json, 'r') as f:
            output_data = json.load(f)
        assert "manually_edited" not in output_data

        # Manual file should still have the edit
        with open(manual_json, 'r') as f:
            manual_data = json.load(f)
        assert manual_data["manually_edited"] is True
