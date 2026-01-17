import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hymn_db.dart';

class HymnDbService {
  static Isar? _isar;
  static const int _currentDbVersion = 14; // Increment this when data structure changes

  static Future<Isar> get isar async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [HymnDbSchema],
      directory: dir.path,
    );

    return _isar!;
  }

  static Future<void> initializeDatabase() async {
    final db = await isar;

    // Check if database needs to be repopulated
    final count = await db.hymnDbs.count();
    final needsRepopulation = count == 0 || await _needsDbUpdate();

    if (needsRepopulation) {
      await populateDatabase();
      await _saveDbVersion();
    }
  }

  static Future<bool> _needsDbUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getInt('hymn_db_version') ?? 0;
      return savedVersion < _currentDbVersion;
    } catch (e) {
      return true; // If we can't read version, assume we need update
    }
  }

  static Future<void> _saveDbVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('hymn_db_version', _currentDbVersion);
    } catch (e) {
      print('Error saving DB version: $e');
    }
  }

  static Future<void> populateDatabase() async {
    final db = await isar;

    // Load available hymns map from assets
    final availableHymnsJson = await rootBundle.loadString('assets/available_hymns.json');
    final Map<String, dynamic> availableHymns = json.decode(availableHymnsJson);

    await db.writeTxn(() async {
      await db.hymnDbs.clear();

      int successCount = 0;
      int errorCount = 0;

      for (final entry in availableHymns.entries) {
        final category = entry.key;
        final hymnNumbers = (entry.value as List).cast<int>();

        for (final number in hymnNumbers) {
          try {
            final content = await rootBundle.loadString('hymns/${category}_$number.json');
            final jsonData = json.decode(content) as Map<String, dynamic>;

            final fileName = '${category}_$number';
            final hymnDb = HymnDb.fromJson(fileName, jsonData);

            await db.hymnDbs.put(hymnDb);
            successCount++;

            if (successCount % 100 == 0) {
              print('  Loaded $successCount hymns...');
            }
          } catch (e) {
            errorCount++;
            print('  Error loading ${category}_$number: $e');
          }
        }
      }

      print('Database populated with $successCount hymns (errors: $errorCount)');
    });
  }

  /// Normalize text for phrase search by removing punctuation and extra spaces
  static String _normalizeForPhraseSearch(String text) {
    // Remove punctuation and normalize spaces
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u4E00-\u9FFF]'), ' ') // Remove punctuation, keep Chinese chars
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse multiple spaces
        .trim();
  }

  static Future<List<HymnDb>> searchHymns(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final db = await isar;

    final searchTerms = query.toLowerCase().split(' ').where((term) => term.isNotEmpty).toList();

    if (searchTerms.isEmpty) {
      return [];
    }

    // For single-word queries, use the limit for performance
    if (searchTerms.length == 1) {
      return await db.hymnDbs
          .filter()
          .fullTextContains(searchTerms.first, caseSensitive: false)
          .or()
          .titleContains(searchTerms.first, caseSensitive: false)
          .sortByNumber()
          .limit(100)
          .findAll();
    }

    // For multi-word phrase searches, don't limit initial results
    // to ensure we don't miss matches in higher-numbered hymns
    final results = await db.hymnDbs
        .filter()
        .fullTextContains(searchTerms.first, caseSensitive: false)
        .or()
        .titleContains(searchTerms.first, caseSensitive: false)
        .sortByNumber()
        .findAll();

    // Perform phrase search (preserve word order)
    final normalizedQuery = _normalizeForPhraseSearch(query);

    final filteredResults = results.where((hymn) {
      final normalizedFullText = _normalizeForPhraseSearch(hymn.fullText);
      final normalizedTitle = _normalizeForPhraseSearch(hymn.title);

      // Check if the phrase appears in order
      return normalizedFullText.contains(normalizedQuery) ||
             normalizedTitle.contains(normalizedQuery);
    }).toList();

    // Apply limit after phrase filtering
    return filteredResults.take(100).toList();
  }

  static Future<HymnDb?> getHymnById(String hymnId) async {
    final db = await isar;
    return await db.hymnDbs
        .filter()
        .hymnIdEqualTo(hymnId)
        .findFirst();
  }

  /// Get all unique categories sorted alphabetically
  static Future<List<String>> getAllCategories() async {
    final db = await isar;
    final allHymns = await db.hymnDbs.where().findAll();
    final categoriesSet = <String>{};
    for (final hymn in allHymns) {
      if (hymn.category.isNotEmpty) {
        categoriesSet.add(hymn.category);
      }
    }
    return categoriesSet.toList()..sort();
  }

  /// Get all hymns in a specific category, sorted by number
  static Future<List<HymnDb>> getHymnsByCategory(String category) async {
    final db = await isar;
    return await db.hymnDbs
        .filter()
        .categoryEqualTo(category, caseSensitive: false)
        .sortByNumber()
        .findAll();
  }

  /// Get category statistics (name → count)
  static Future<Map<String, int>> getCategoryStats() async {
    final db = await isar;
    final allHymns = await db.hymnDbs.where().findAll();
    final stats = <String, int>{};
    for (final hymn in allHymns) {
      if (hymn.category.isNotEmpty) {
        stats[hymn.category] = (stats[hymn.category] ?? 0) + 1;
      }
    }
    return Map.fromEntries(
      stats.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
  }

  /// Check if a lyricist's last name is a single letter (should be excluded from index)
  static bool _hasSingleLetterLastName(String lyricist) {
    final parts = lyricist.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return false;
    final lastName = parts.last.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    return lastName.length == 1;
  }

  /// Get all unique lyricists sorted alphabetically
  /// Excludes lyricists whose last name is a single letter
  static Future<List<String>> getAllLyricists() async {
    final db = await isar;
    final allHymns = await db.hymnDbs.where().findAll();
    final lyricistsSet = <String>{};
    for (final hymn in allHymns) {
      if (hymn.lyricist != null &&
          hymn.lyricist!.isNotEmpty &&
          !_hasSingleLetterLastName(hymn.lyricist!)) {
        lyricistsSet.add(hymn.lyricist!);
      }
    }
    return lyricistsSet.toList()..sort();
  }

  /// Get all hymns by a specific lyricist, sorted by number
  static Future<List<HymnDb>> getHymnsByLyricist(String lyricist) async {
    final db = await isar;
    return await db.hymnDbs
        .filter()
        .lyricistEqualTo(lyricist, caseSensitive: false)
        .sortByNumber()
        .findAll();
  }

  /// Get lyricist statistics (name → count)
  /// Only includes lyricists with more than one hymn
  /// Excludes lyricists whose last name is a single letter
  static Future<Map<String, int>> getLyricistStats() async {
    final db = await isar;
    final allHymns = await db.hymnDbs.where().findAll();
    final stats = <String, int>{};
    for (final hymn in allHymns) {
      if (hymn.lyricist != null &&
          hymn.lyricist!.isNotEmpty &&
          !_hasSingleLetterLastName(hymn.lyricist!)) {
        stats[hymn.lyricist!] = (stats[hymn.lyricist!] ?? 0) + 1;
      }
    }
    // Filter to only include lyricists with more than one hymn
    final filteredStats = Map<String, int>.fromEntries(
      stats.entries.where((entry) => entry.value > 1)
    );
    return Map.fromEntries(
      filteredStats.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
