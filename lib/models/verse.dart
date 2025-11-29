import 'line.dart';

class Verse {
  final List<Line> lines;

  Verse({
    required this.lines,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      lines: (json['lines'] as List<dynamic>?)
              ?.map((line) => Line.fromJson(line as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lines': lines.map((line) => line.toJson()).toList(),
    };
  }
}
