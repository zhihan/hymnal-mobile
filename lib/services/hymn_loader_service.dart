import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/hymn_song.dart';

class HymnLoaderService {
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

  /// Get list of available hymn numbers (1-20 based on the files you have)
  static List<int> getAvailableHymnNumbers() {
    return List.generate(20, (index) => index + 1);
  }
}
