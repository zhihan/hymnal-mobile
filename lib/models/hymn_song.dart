import 'verse.dart';
import 'hymn_version.dart';
import 'melody.dart';

class HymnSong {
  final String url;
  final String title;
  final List<Verse> verses;
  final Map<String, dynamic>? metadata;
  final List<HymnVersion>? alternateVersions;

  HymnSong({
    required this.url,
    required this.title,
    required this.verses,
    this.metadata,
    this.alternateVersions,
  });

  bool get hasAlternateVersions =>
      alternateVersions != null && alternateVersions!.isNotEmpty;

  Melody? get melody {
    final value = metadata?['melody'];
    if (value is! Map<String, dynamic>) return null;
    try {
      return Melody.fromJson(value);
    } on FormatException {
      // Unsupported/corrupt melody (e.g. a not-yet-migrated v1 file). This
      // getter is read from build(), so throwing here would replace the
      // whole hymn page with an error widget. Degrade to "no tablature"
      // instead: the Guitar Tab button hides and the lyrics still render.
      return null;
    } on TypeError {
      return null;
    }
  }

  factory HymnSong.fromJson(Map<String, dynamic> json) {
    return HymnSong(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      verses:
          (json['verses'] as List<dynamic>?)
              ?.map((verse) => Verse.fromJson(verse as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>?,
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
      if (alternateVersions != null)
        'alternate_versions': alternateVersions!
            .map((v) => v.toJson())
            .toList(),
    };
  }
}
