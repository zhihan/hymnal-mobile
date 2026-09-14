import 'package:flutter_test/flutter_test.dart';
import 'package:hymns_mobile/models/melody.dart';

void main() {
  test('decodes v2 duration/pitch-delta pairs with a rest', () {
    final melody = Melody.fromJson({
      'v': 2,
      'n': [
        [384, 60],
        [192, 2],
        [192, -2],
        ['R', 384],
        [768, 5],
      ],
    });

    expect(melody.ticksPerBeat, 384);
    expect(melody.notes, hasLength(4));

    final starts = melody.notes.map((note) => note.start).toList();
    final durations = melody.notes.map((note) => note.duration).toList();
    final pitches = melody.notes.map((note) => note.pitch).toList();
    expect(starts, [0, 384, 576, 1152]);
    expect(durations, [384, 192, 192, 768]);
    expect(pitches, [60, 62, 60, 65]);
  });

  test('decodes an empty v2 note list', () {
    final melody = Melody.fromJson({
      'v': 2,
      'n': [],
    });

    expect(melody.notes, isEmpty);
  });

  test('rejects the v1 format', () {
    expect(
      () => Melody.fromJson({
        'version': 1,
        'ticks_per_beat': 384,
        'notes': [
          {'start': 0, 'duration': 384, 'pitch': 60},
        ],
      }),
      throwsFormatException,
    );
  });

  test('rejects a missing version', () {
    expect(
      () => Melody.fromJson({
        'n': [
          [384, 60],
        ],
      }),
      throwsFormatException,
    );
  });
}
