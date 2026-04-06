import 'verse.dart';
import 'hymn_version.dart';

class HymnSong {
  final String url;
  final String title;
  final List<Verse> verses;
  final Map<String, dynamic>? metadata;
  final List<String>? rawSections;
  final List<HymnVersion>? alternateVersions;

  HymnSong({
    required this.url,
    required this.title,
    required this.verses,
    this.metadata,
    this.rawSections,
    this.alternateVersions,
  });

  bool get hasAlternateVersions =>
      alternateVersions != null && alternateVersions!.isNotEmpty;

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
      alternateVersions: (json['alternate_versions'] as List<dynamic>?)
          ?.map((v) => HymnVersion.fromJson(v as Map<String, dynamic>))
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
      if (alternateVersions != null)
        'alternate_versions':
            alternateVersions!.map((v) => v.toJson()).toList(),
    };
  }
}
