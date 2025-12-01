import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hymn_db.dart';

class HymnDbService {
  static Isar? _isar;

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

    final count = await db.hymnDbs.count();
    if (count > 0) {
      return;
    }

    await populateDatabase();
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

  static Future<List<HymnDb>> searchHymns(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final db = await isar;

    final searchTerms = query.toLowerCase().split(' ').where((term) => term.isNotEmpty).toList();

    if (searchTerms.isEmpty) {
      return [];
    }

    final results = await db.hymnDbs
        .filter()
        .fullTextContains(searchTerms.first, caseSensitive: false)
        .or()
        .titleContains(searchTerms.first, caseSensitive: false)
        .sortByNumber()
        .limit(100)
        .findAll();

    if (searchTerms.length == 1) {
      return results;
    }

    return results.where((hymn) {
      final lowerFullText = hymn.fullText.toLowerCase();
      final lowerTitle = hymn.title.toLowerCase();
      return searchTerms.every((term) =>
          lowerFullText.contains(term) || lowerTitle.contains(term));
    }).toList();
  }

  static Future<HymnDb?> getHymnById(String hymnId) async {
    final db = await isar;
    return await db.hymnDbs
        .filter()
        .hymnIdEqualTo(hymnId)
        .findFirst();
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
