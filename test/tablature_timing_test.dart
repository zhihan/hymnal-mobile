import 'package:flutter_test/flutter_test.dart';
import 'package:hymns_mobile/models/melody.dart';
import 'package:hymns_mobile/screens/tablature_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows time signature and tempo left of the capo selector', (
    tester,
  ) async {
    const melody = Melody(
      ticksPerBeat: 480,
      tempoBpm: 96,
      timeSignature: [3, 4],
      notes: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: TablatureScreen(melody: melody, hymnTitle: 'Test Hymn'),
      ),
    );

    expect(find.text('3/4 · 96 BPM'), findsOneWidget);

    final timingCenter = tester.getCenter(find.text('3/4 · 96 BPM'));
    final capoCenter = tester.getCenter(find.text('Capo'));
    expect(timingCenter.dx, lessThan(capoCenter.dx));
  });

  testWidgets('formats fractional tempos without trailing zeros', (
    tester,
  ) async {
    const melody = Melody(
      ticksPerBeat: 480,
      tempoBpm: 100.5,
      timeSignature: [4, 4],
      notes: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: TablatureScreen(melody: melody, hymnTitle: 'Test Hymn'),
      ),
    );

    expect(find.text('4/4 · 100.5 BPM'), findsOneWidget);
  });
}
