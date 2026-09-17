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
  /// ticks_per_beat is 384 for every melody in the corpus, so v2 does not
  /// store it per file; the decoder treats it as a constant.
  static const int v2TicksPerBeat = 384;
  static const int v2Version = 2;

  final int ticksPerBeat;
  final List<int> timeSignature;
  final List<MelodyNote> notes;

  const Melody({
    required this.ticksPerBeat,
    required this.timeSignature,
    required this.notes,
  });

  /// Decodes the v2 compact encoding:
  /// `{"v": 2, "ts": [num, den], "n": [[duration, pitchOrDelta], ..., ["R", ticks]]}`.
  ///
  /// The first entry carries the absolute pitch; later entries carry the
  /// delta from the previous pitch. Note start times are reconstructed by
  /// accumulating durations, so only gaps are stored explicitly as
  /// `["R", ticks]` rests. Throws [FormatException] on any other version.
  factory Melody.fromJson(Map<String, dynamic> json) {
    final version = (json['v'] as num?)?.toInt();
    if (version != v2Version) {
      throw FormatException(
        'Unsupported melody version: ${json['v'] ?? json['version'] ?? 'missing'} '
        '(expected $v2Version)',
      );
    }
    var cursor = 0;
    int? pitch;
    final notes = <MelodyNote>[];
    for (final entry in (json['n'] as List<dynamic>? ?? const [])) {
      final pair = entry as List<dynamic>;
      if (pair[0] == 'R') {
        cursor += (pair[1] as num).toInt();
        continue;
      }
      final duration = (pair[0] as num).toInt();
      final delta = (pair[1] as num).toInt();
      final nextPitch = pitch == null ? delta : pitch + delta;
      pitch = nextPitch;
      notes.add(
        MelodyNote(start: cursor, duration: duration, pitch: nextPitch),
      );
      cursor += duration;
    }
    final rawSignature = json['ts'] as List<dynamic>?;
    final timeSignature = rawSignature != null && rawSignature.length == 2
        ? rawSignature.map((value) => (value as num).toInt()).toList()
        : const [4, 4];
    return Melody(
      ticksPerBeat: v2TicksPerBeat,
      timeSignature: timeSignature,
      notes: notes,
    );
  }
}
