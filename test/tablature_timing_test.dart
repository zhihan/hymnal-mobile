import 'package:flutter_test/flutter_test.dart';
import 'package:hymns_mobile/models/melody.dart';
import 'package:hymns_mobile/screens/tablature_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows time signature left of the capo selector', (tester) async {
    const melody = Melody(ticksPerBeat: 480, timeSignature: [3, 4], notes: []);

    await tester.pumpWidget(
      const MaterialApp(
        home: TablatureScreen(melody: melody, hymnTitle: 'Test Hymn'),
      ),
    );

    expect(find.text('3/4'), findsOneWidget);

    final timingCenter = tester.getCenter(find.text('3/4'));
    final capoCenter = tester.getCenter(find.text('Capo'));
    expect(timingCenter.dx, lessThan(capoCenter.dx));
  });
}
