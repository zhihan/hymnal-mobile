import 'dart:convert';
import 'dart:io';
import '../models/song_list.dart';

/// Service for sharing and importing song lists via URL
class SongListShareService {
  static const String _baseUrl = 'https://cicmusic.net/songlist';
  static const String _version = 'v1';

  /// Encode a song list into a shareable URL
  ///
  /// Format: https://cicmusic.net/songlist/v1:<base64url-gzipped-json>
  static String generateShareUrl(SongList songList) {
    // Create minimal JSON structure
    final minimalData = {
      'n': songList.name,
      'h': songList.hymnIds,
    };

    // Convert to JSON string
    final jsonString = jsonEncode(minimalData);

    // Compress and encode
    final encoded = _compressAndEncode(jsonString);

    // Generate URL with version prefix
    return '$_baseUrl/$_version:$encoded';
  }

  /// Decode a shareable URL/encoded string back to song list data
  ///
  /// Returns a Map with 'name' and 'hymnIds' keys
  /// Throws FormatException if invalid
  static Map<String, dynamic> decodeSongListData(String encodedData) {
    String dataToProcess = encodedData;

    // Remove base URL if present
    if (encodedData.startsWith(_baseUrl)) {
      dataToProcess = encodedData.substring(_baseUrl.length + 1); // +1 for the /
    }

    // Check for version prefix
    if (dataToProcess.startsWith('$_version:')) {
      dataToProcess = dataToProcess.substring(_version.length + 1); // +1 for the :
      // Version 1 format - decompress and decode
      return _decodeAndDecompress(dataToProcess);
    } else {
      // No version prefix - try to decode as v1 format (backward compatible)
      try {
        return _decodeAndDecompress(dataToProcess);
      } catch (e) {
        throw FormatException('Invalid or unsupported song list format: $e');
      }
    }
  }

  /// Generate a unique name for imported song list
  ///
  /// If a list with [baseName] exists, appends " (2)", " (3)", etc.
  static String generateUniqueName(String baseName, List<SongList> existingLists) {
    // Check if base name is unique
    final existingNames = existingLists.map((list) => list.name).toSet();

    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    // Find unique suffix
    int suffix = 2;
    while (existingNames.contains('$baseName ($suffix)')) {
      suffix++;
    }

    return '$baseName ($suffix)';
  }

  /// Compress JSON string with gzip and encode as base64url
  static String _compressAndEncode(String jsonString) {
    // Convert to bytes
    final bytes = utf8.encode(jsonString);

    // Compress with gzip
    final compressed = gzip.encode(bytes);

    // Encode as base64url (URL-safe, no padding)
    final encoded = base64Url.encode(compressed).replaceAll('=', '');

    return encoded;
  }

  /// Decode base64url and decompress with gzip
  static Map<String, dynamic> _decodeAndDecompress(String encoded) {
    try {
      // Add padding back if needed (base64 requires length to be multiple of 4)
      String padded = encoded;
      while (padded.length % 4 != 0) {
        padded += '=';
      }

      // Decode from base64url
      final compressed = base64Url.decode(padded);

      // Decompress with gzip
      final bytes = gzip.decode(compressed);

      // Convert to string
      final jsonString = utf8.decode(bytes);

      // Parse JSON
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Validate and expand to expected format
      if (!data.containsKey('n') || !data.containsKey('h')) {
        throw FormatException('Missing required fields in song list data');
      }

      return {
        'name': data['n'] as String,
        'hymnIds': (data['h'] as List<dynamic>).cast<String>(),
      };
    } catch (e) {
      throw FormatException('Failed to decode song list data: $e');
    }
  }

  /// Validate hymn IDs format (basic validation)
  ///
  /// Returns true if all hymn IDs follow expected format
  static bool validateHymnIds(List<String> hymnIds) {
    if (hymnIds.isEmpty) {
      return true; // Allow empty lists
    }

    // Check each hymn ID follows pattern: {bookId}_{number}
    final hymnIdPattern = RegExp(r'^[a-z]+_\d+$');

    return hymnIds.every((id) => hymnIdPattern.hasMatch(id));
  }
}
