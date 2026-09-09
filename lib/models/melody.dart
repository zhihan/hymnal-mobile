class MelodyNote {
  final int start;
  final int duration;
  final int pitch;

  const MelodyNote({
    required this.start,
    required this.duration,
    required this.pitch,
  });

  factory MelodyNote.fromJson(Map<String, dynamic> json) => MelodyNote(
    start: (json['start'] as num).toInt(),
    duration: (json['duration'] as num).toInt(),
    pitch: (json['pitch'] as num).toInt(),
  );
}

class Melody {
  final int ticksPerBeat;
  final double tempoBpm;
  final List<int> timeSignature;
  final List<MelodyNote> notes;

  const Melody({
    required this.ticksPerBeat,
    required this.tempoBpm,
    required this.timeSignature,
    required this.notes,
  });

  factory Melody.fromJson(Map<String, dynamic> json) => Melody(
    ticksPerBeat: (json['ticks_per_beat'] as num).toInt(),
    tempoBpm: (json['tempo_bpm'] as num?)?.toDouble() ?? 120,
    timeSignature:
        (json['time_signature'] as List<dynamic>?)
            ?.map((value) => (value as num).toInt())
            .toList() ??
        const [4, 4],
    notes: (json['notes'] as List<dynamic>? ?? const [])
        .map((note) => MelodyNote.fromJson(note as Map<String, dynamic>))
        .toList(),
  );
}
