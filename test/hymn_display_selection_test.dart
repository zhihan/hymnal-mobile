import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymns_mobile/models/hymn_song.dart';
import 'package:hymns_mobile/models/line.dart';
import 'package:hymns_mobile/models/segment.dart';
import 'package:hymns_mobile/models/verse.dart';
import 'package:hymns_mobile/widgets/hymn_display.dart';
import 'package:material_ui/material_ui.dart';

HymnSong _testHymn() => HymnSong(
      url: 'https://example.com/hymn',
      title: 'Test Hymn',
      verses: [
        Verse(
          type: 'verse',
          number: '1',
          lines: [
            Line(segments: [
              Segment(chord: '', text: 'What a w'),
              Segment(chord: 'G', text: 'onderful '),
              Segment(chord: 'C', text: 'change'),
            ]),
          ],
        ),
      ],
    );

void main() {
  testWidgets('lyrics are selectable and copy excludes chords', (tester) async {
    // Capture what gets written to the clipboard.
    final List<MethodCall> clipboardLog = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        clipboardLog.add(call);
        return null;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HymnDisplay(hymn: _testHymn())),
      ),
    );

    // Lyric text lives inside a SelectionArea.
    expect(
      find.ancestor(
        of: find.text('onderful '),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );

    // Chord labels are wrapped in a disabled SelectionContainer so they
    // are not part of the selection.
    final chord = find.text('G');
    expect(chord, findsOneWidget);
    expect(
      find.ancestor(
        of: chord,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SelectionContainer && widget.delegate == null,
        ),
      ),
      findsOneWidget,
    );

    // Long-press to select, then select all and copy via the toolbar.
    await tester.longPress(find.text('onderful '));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pump();

    final copyCall = clipboardLog.lastWhere(
      (call) => call.method == 'Clipboard.setData',
    );
    final copiedText = (copyCall.arguments as Map)['text'] as String;
    expect(copiedText, contains('What a wonderful change'));
    expect(copiedText, isNot(contains('G')));
    expect(copiedText, isNot(contains('C')));
  });
}
