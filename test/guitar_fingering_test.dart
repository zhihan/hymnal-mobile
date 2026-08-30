import 'package:flutter_test/flutter_test.dart';
import 'package:hymns_mobile/models/melody.dart';
import 'package:hymns_mobile/utils/guitar_fingering.dart';

void main() {
  test('capo changes fret numbers while preserving sounding pitch', () {
    const note = MelodyNote(start: 0, duration: 480, pitch: 64);

    final open = GuitarFingering.positionsForPitch(note.pitch, capo: 0);
    final capoTwo = GuitarFingering.positionsForPitch(note.pitch, capo: 2);

    expect(
      open.any((position) => position.stringNumber == 1 && position.fret == 0),
      isTrue,
    );
    expect(
      capoTwo.any(
        (position) => position.stringNumber == 2 && position.fret == 3,
      ),
      isTrue,
    );
    expect(capoTwo.any((position) => position.stringNumber == 1), isFalse);
  });

  test('arranger returns a position for every playable note', () {
    const notes = [
      MelodyNote(start: 0, duration: 480, pitch: 60),
      MelodyNote(start: 480, duration: 480, pitch: 62),
      MelodyNote(start: 960, duration: 480, pitch: 64),
    ];

    final result = GuitarFingering.arrange(notes);

    expect(result, hasLength(3));
    expect(result.every((note) => note.position != null), isTrue);
  });

  test('arranger shifts melody down an octave for guitar range', () {
    // Melody pitch 64 (E4) is extracted at vocal pitch; the arranger should
    // fret it as if it were 52 (E3) so tabs land in a playable register
    // instead of climbing straight to the open high E string.
    const notes = [MelodyNote(start: 0, duration: 480, pitch: 64)];

    final result = GuitarFingering.arrange(notes);

    expect(result.single.position?.stringNumber, 4);
    expect(result.single.position?.fret, 2);
  });

  test(
    'arranger prefers switching strings over sliding one string across frets',
    () {
      const notes = [
        MelodyNote(start: 0, duration: 480, pitch: 63),
        MelodyNote(start: 480, duration: 480, pitch: 63),
        MelodyNote(start: 960, duration: 480, pitch: 63),
        MelodyNote(start: 1440, duration: 480, pitch: 72),
      ];

      final result = GuitarFingering.arrange(notes);
      final frets = result.map((note) => note.position!.fret).toList();
      final strings = result
          .map((note) => note.position!.stringNumber)
          .toList();

      // All four notes stay within the same one-fret hand region...
      expect(frets, [1, 1, 1, 1]);
      // ...while the string changes to reach the higher note instead of
      // sliding the same string up several frets.
      expect(strings, [4, 4, 4, 2]);
    },
  );

  test(
    'arranger prefers a nearby open string over fretting the same string',
    () {
      // Fret 5 on one string sounds the same pitch as open on the next
      // string up. Given the choice, the arranger should take the open
      // string - it needs no left-hand finger at all.
      const notes = [
        MelodyNote(
          start: 0,
          duration: 480,
          pitch: 68,
        ), // fret 1 on the G string
        MelodyNote(
          start: 480,
          duration: 480,
          pitch: 67,
        ), // open G is available here
      ];

      final result = GuitarFingering.arrange(notes);

      expect(result[0].position?.stringNumber, 3);
      expect(result[0].position?.fret, 1);
      expect(result[1].position?.stringNumber, 3);
      expect(result[1].position?.fret, 0);
    },
  );
}
