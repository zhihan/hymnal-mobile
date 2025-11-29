class Chord {
  final int position;
  final String chord;

  Chord({
    required this.position,
    required this.chord,
  });

  factory Chord.fromJson(Map<String, dynamic> json) {
    return Chord(
      position: json['position'] as int,
      chord: json['chord'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'position': position,
      'chord': chord,
    };
  }
}
