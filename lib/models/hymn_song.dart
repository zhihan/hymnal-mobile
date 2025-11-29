import 'line.dart';

class HymnSong {
  final String url;
  final String title;
  final List<Line> lines;
  final Map<String, dynamic>? metadata;
  final List<String>? rawSections;

  HymnSong({
    required this.url,
    required this.title,
    required this.lines,
    this.metadata,
    this.rawSections,
  });

  factory HymnSong.fromJson(Map<String, dynamic> json) {
    return HymnSong(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      lines: (json['lines'] as List<dynamic>?)
              ?.map((line) => Line.fromJson(line as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>?,
      rawSections: (json['raw_sections'] as List<dynamic>?)
          ?.map((section) => section as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'lines': lines.map((line) => line.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
      if (rawSections != null) 'raw_sections': rawSections,
    };
  }
}
