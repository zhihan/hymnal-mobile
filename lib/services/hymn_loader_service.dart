import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/hymn_song.dart';

class HymnLoaderService {
  // Cache for available hymn numbers by category
  static Map<String, List<int>>? _cachedAvailableNumbers;
  static Map<String, String>? _cachedCategoryDisplayNames;

  /// Load a hymn from a JSON file in the assets
  static Future<HymnSong> loadHymn(String fileName) async {
    try {
      final String jsonString = await rootBundle.loadString('hymns/$fileName');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return HymnSong.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to load hymn $fileName: $e');
    }
  }

  /// Load a hymn by category and number (e.g., 'ts', 1 loads ts_1.json)
  static Future<HymnSong> loadHymnByNumber(String category, int number) async {
    return loadHymn('${category}_$number.json');
  }

  /// Get all available categories with their display names
  static Future<Map<String, String>> getCategories() async {
    if (_cachedCategoryDisplayNames != null) {
      return _cachedCategoryDisplayNames!;
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/available_hymns.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      final Map<String, String> result = {
        'h': 'Hymns',
        'ch': '大本',
        'ts': '补充本',
        'ns': 'New Songs',
      };

      // Filter out categories that don't exist in the JSON
      result.removeWhere((key, _) => !jsonData.containsKey(key));

      _cachedCategoryDisplayNames = result;
      return result;
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  /// Get list of available hymn numbers for a specific category
  static Future<List<int>> getAvailableHymnNumbers(String category) async {
    // Return cached list if available
    if (_cachedAvailableNumbers != null &&
        _cachedAvailableNumbers!.containsKey(category)) {
      return _cachedAvailableNumbers![category]!;
    }

    try {
      // Load the available hymns JSON file
      final String jsonString = await rootBundle.loadString('assets/available_hymns.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      // Extract the array of hymn numbers for this category
      if (!jsonData.containsKey(category)) {
        throw Exception('Category $category not found');
      }

      final List<dynamic> numbersJson = jsonData[category];
      final hymnNumbers = numbersJson.cast<int>();

      // Cache the result
      _cachedAvailableNumbers ??= {};
      _cachedAvailableNumbers![category] = hymnNumbers;

      return hymnNumbers;
    } catch (e) {
      throw Exception('Failed to load available hymn numbers for $category: $e');
    }
  }

  /// Get the next available hymn number after the given number in a category
  /// Returns null if there is no next hymn
  static Future<int?> getNextHymnNumber(String category, int currentNumber) async {
    final availableNumbers = await getAvailableHymnNumbers(category);

    for (final number in availableNumbers) {
      if (number > currentNumber) {
        return number;
      }
    }

    return null; // No next hymn
  }

  /// Get the previous available hymn number before the given number in a category
  /// Returns null if there is no previous hymn
  static Future<int?> getPreviousHymnNumber(String category, int currentNumber) async {
    final availableNumbers = await getAvailableHymnNumbers(category);

    // Iterate in reverse to find the first number less than current
    for (int i = availableNumbers.length - 1; i >= 0; i--) {
      if (availableNumbers[i] < currentNumber) {
        return availableNumbers[i];
      }
    }

    return null; // No previous hymn
  }

  /// Clear the cache (useful when hymn database is updated)
  static void clearCache() {
    _cachedAvailableNumbers = null;
    _cachedCategoryDisplayNames = null;
  }
}
