import 'chord.dart';

class LyricLine {
  final String line;
  final List<Chord> chords;

  LyricLine({
    required this.line,
    required this.chords,
  });

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      line: json['line'] as String,
      chords: (json['chords'] as List<dynamic>?)
              ?.map((chord) => Chord.fromJson(chord as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'line': line,
      'chords': chords.map((chord) => chord.toJson()).toList(),
    };
  }
}
