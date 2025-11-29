import 'segment.dart';

class Line {
  final List<Segment> segments;

  Line({
    required this.segments,
  });

  factory Line.fromJson(Map<String, dynamic> json) {
    return Line(
      segments: (json['segments'] as List<dynamic>?)
              ?.map((segment) => Segment.fromJson(segment as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'segments': segments.map((segment) => segment.toJson()).toList(),
    };
  }
}
