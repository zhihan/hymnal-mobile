import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/hymn_song.dart';

class HymnLoaderService {
  // Cache for available hymn numbers to avoid repeated manifest parsing
  static List<int>? _cachedAvailableNumbers;

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

  /// Load a hymn by number (e.g., 1 loads ts_1.json)
  static Future<HymnSong> loadHymnByNumber(int number) async {
    return loadHymn('ts_$number.json');
  }

  /// Get list of available hymn numbers by scanning the asset manifest
  /// This works for local files and can be extended for online sources
  static Future<List<int>> getAvailableHymnNumbers() async {
    // Return cached list if available
    if (_cachedAvailableNumbers != null) {
      return _cachedAvailableNumbers!;
    }

    try {
      // Load the asset manifest
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // Extract hymn numbers from file paths
      final hymnNumbers = <int>[];
      final hymnPattern = RegExp(r'hymns/ts_(\d+)\.json');

      for (final String key in manifestMap.keys) {
        final match = hymnPattern.firstMatch(key);
        if (match != null) {
          final number = int.parse(match.group(1)!);
          hymnNumbers.add(number);
        }
      }

      // Sort the numbers
      hymnNumbers.sort();

      // Cache the result
      _cachedAvailableNumbers = hymnNumbers;

      return hymnNumbers;
    } catch (e) {
      // Fallback: return empty list or throw exception
      throw Exception('Failed to load available hymn numbers: $e');
    }
  }

  /// Get the next available hymn number after the given number
  /// Returns null if there is no next hymn
  static Future<int?> getNextHymnNumber(int currentNumber) async {
    final availableNumbers = await getAvailableHymnNumbers();

    for (final number in availableNumbers) {
      if (number > currentNumber) {
        return number;
      }
    }

    return null; // No next hymn
  }

  /// Get the previous available hymn number before the given number
  /// Returns null if there is no previous hymn
  static Future<int?> getPreviousHymnNumber(int currentNumber) async {
    final availableNumbers = await getAvailableHymnNumbers();

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
  }
}
