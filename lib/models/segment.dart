class Segment {
  final String chord;
  final String text;

  Segment({
    required this.chord,
    required this.text,
  });

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      chord: json['chord'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chord': chord,
      'text': text,
    };
  }
}
