import 'verse.dart';

class HymnSong {
  final String url;
  final String title;
  final List<Verse> verses;
  final Map<String, dynamic>? metadata;
  final List<String>? rawSections;

  HymnSong({
    required this.url,
    required this.title,
    required this.verses,
    this.metadata,
    this.rawSections,
  });

  factory HymnSong.fromJson(Map<String, dynamic> json) {
    return HymnSong(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      verses: (json['verses'] as List<dynamic>?)
              ?.map((verse) => Verse.fromJson(verse as Map<String, dynamic>))
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
      'verses': verses.map((verse) => verse.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
      if (rawSections != null) 'raw_sections': rawSections,
    };
  }
}
