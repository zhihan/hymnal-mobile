import 'package:isar/isar.dart';

part 'hymn_db.g.dart';

@collection
class HymnDb {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String hymnId;

  @Index(type: IndexType.value)
  late String title;

  late int number;

  @Index(type: IndexType.value, caseSensitive: false)
  late String fullText;

  late String url;

  @Index(type: IndexType.value)
  late String bookId;

  @Index(type: IndexType.value, caseSensitive: false)
  late String category;

  String? time;

  String? hymnCode;

  @Index(type: IndexType.value, caseSensitive: false)
  String? lyricist;

  late bool hasAlternateVersions;

  HymnDb();

  String extractFullText(Map<String, dynamic> json) {
    final StringBuffer buffer = StringBuffer();

    buffer.write(json['title'] ?? '');
    buffer.write(' ');

    final verses = json['verses'] as List<dynamic>?;
    if (verses != null) {
      for (var verse in verses) {
        final lines = verse['lines'] as List<dynamic>?;
        if (lines != null) {
          for (var line in lines) {
            final segments = line['segments'] as List<dynamic>?;
            if (segments != null) {
              for (var segment in segments) {
                final text = segment['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  buffer.write(text);
                  buffer.write(' ');
                }
              }
            }
          }
        }
      }
    }

    String result = buffer.toString().trim();

    // Remove spaces between Chinese characters for Chinese hymn books
    result = _removeSpacesBetweenChinese(result);

    return result;
  }

  String _removeSpacesBetweenChinese(String text) {
    // Regular expression to match Chinese characters (CJK Unified Ideographs)
    // Unicode range: U+4E00 to U+9FFF covers most common Chinese characters
    final chineseCharPattern = RegExp(r'[\u4E00-\u9FFF]');

    final StringBuffer result = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      // Skip spaces between Chinese characters
      if (char == ' ' && i > 0 && i < text.length - 1) {
        final prevChar = text[i - 1];
        final nextChar = text[i + 1];

        if (chineseCharPattern.hasMatch(prevChar) && chineseCharPattern.hasMatch(nextChar)) {
          // Skip this space
          continue;
        }
      }

      // Add the current character
      result.write(char);
    }

    return result.toString();
  }

  factory HymnDb.fromJson(String hymnId, Map<String, dynamic> json) {
    final hymn = HymnDb();
    hymn.hymnId = hymnId;
    hymn.title = json['title'] as String? ?? '';
    hymn.url = json['url'] as String? ?? '';

    final hymnIdParts = hymnId.split('_');
    if (hymnIdParts.length == 2) {
      hymn.bookId = hymnIdParts[0];
      hymn.number = int.tryParse(hymnIdParts[1]) ?? 0;
    } else {
      hymn.bookId = '';
      hymn.number = 0;
    }

    final metadata = json['metadata'] as Map<String, dynamic>?;
    hymn.category = metadata?['category'] as String? ?? '';
    hymn.time = metadata?['time'] as String?;
    hymn.hymnCode = metadata?['hymn_code'] as String?;
    hymn.lyricist = metadata?['lyrics'] as String?;

    hymn.fullText = hymn.extractFullText(json);
    hymn.hasAlternateVersions =
        (json['alternate_versions'] as List<dynamic>?)?.isNotEmpty ?? false;

    return hymn;
  }
}
