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

  late String category;

  String? time;

  String? hymnCode;

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

    return buffer.toString().trim();
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

    hymn.fullText = hymn.extractFullText(json);

    return hymn;
  }
}
