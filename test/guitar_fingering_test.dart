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
}
