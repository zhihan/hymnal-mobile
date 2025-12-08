import 'line.dart';

class Verse {
  final List<Line> lines;
  final String? type; // 'verse' or 'chorus'
  final String? number; // verse number (only for type='verse')

  Verse({
    required this.lines,
    this.type,
    this.number,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      lines: (json['lines'] as List<dynamic>?)
              ?.map((line) => Line.fromJson(line as Map<String, dynamic>))
              .toList() ??
          [],
      type: json['type'] as String?,
      number: json['number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'lines': lines.map((line) => line.toJson()).toList(),
    };
    if (type != null) map['type'] = type;
    if (number != null) map['number'] = number;
    return map;
  }
}
