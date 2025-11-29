import 'lyric_line.dart';

class Hymn {
  final String id;
  final String title;
  final int number;
  final List<LyricLine> lyrics;
  final Map<String, dynamic>? metadata;

  Hymn({
    required this.id,
    required this.title,
    required this.number,
    required this.lyrics,
    this.metadata,
  });

  factory Hymn.fromJson(String id, Map<String, dynamic> json) {
    return Hymn(
      id: id,
      title: json['title'] as String,
      number: json['number'] as int,
      lyrics: (json['lyrics'] as List<dynamic>?)
              ?.map((line) => LyricLine.fromJson(line as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'number': number,
      'lyrics': lyrics.map((line) => line.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}
