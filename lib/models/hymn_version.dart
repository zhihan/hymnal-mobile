import 'verse.dart';

/// An alternate version of a hymn from a different source.
class HymnVersion {
  final String source;
  final String title;
  final String url;
  final List<Verse> verses;
  final Map<String, dynamic>? metadata;

  HymnVersion({
    required this.source,
    required this.title,
    required this.url,
    required this.verses,
    this.metadata,
  });

  factory HymnVersion.fromJson(Map<String, dynamic> json) {
    return HymnVersion(
      source: json['source'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      verses: (json['verses'] as List<dynamic>?)
              ?.map((verse) => Verse.fromJson(verse as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'title': title,
      'url': url,
      'verses': verses.map((verse) => verse.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}
