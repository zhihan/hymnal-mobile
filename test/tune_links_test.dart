import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymns_mobile/providers/song_list_provider.dart';
import 'package:hymns_mobile/providers/theme_provider.dart';
import 'package:hymns_mobile/screens/hymn_detail_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _hymnJson(String title, List<Map<String, String>>? tuneLinks) {
  return json.encode({
    'url': 'https://www.hymnal.net/en/hymn/nt/12',
    'title': title,
    'verses': [
      {
        'lines': [
          {
            'segments': [
              {'chord': 'C', 'text': 'line one'},
            ],
          },
        ],
      },
    ],
    'metadata': {
      if (tuneLinks != null) 'tune_links': tuneLinks,
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpTuneLinkScreen(
    WidgetTester tester, {
    required String bookId,
    required int hymnNumber,
    required List<Map<String, String>>? tuneLinks,
  }) async {
    final ntJson = _hymnJson('NT hymn', tuneLinks);
    final hJson = _hymnJson('H hymn', [
      {'category': 'nt', 'number': '12', 'label': 'New Tune'},
    ]);
    // rootBundle caches loaded strings across tests; evict so each test
    // serves its own mock assets.
    rootBundle.evict('assets/available_hymns.json');
    rootBundle.evict('hymns/nt_12.json');
    rootBundle.evict('hymns/h_12.json');
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        final asset = <String, String>{
          'assets/available_hymns.json': json.encode({
            'nt': [12],
            'h': [12],
          }),
          'hymns/nt_12.json': ntJson,
          'hymns/h_12.json': hJson,
        }[key];
        if (asset == null) return null;
        final bytes = Uint8List.fromList(utf8.encode(asset));
        return ByteData.view(bytes.buffer);
      },
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SongListProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          home: HymnDetailScreen(
            initialHymnNumber: hymnNumber,
            bookId: bookId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tune links appear in the version selector panel',
      (tester) async {
    await pumpTuneLinkScreen(
      tester,
      bookId: 'nt',
      hymnNumber: 12,
      tuneLinks: [
        {'category': 'h', 'number': '12', 'label': 'Original Tune'},
      ],
    );

    // The version icon shows because tune links exist (no related hymns).
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);

    // Panel is hidden until toggled.
    expect(find.text('H12'), findsNothing);

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();

    // Tune link shares the single-row selector with language links.
    expect(find.text('H12'), findsOneWidget);
  });

  testWidgets('tapping a tune link navigates across books', (tester) async {
    await pumpTuneLinkScreen(
      tester,
      bookId: 'nt',
      hymnNumber: 12,
      tuneLinks: [
        {'category': 'h', 'number': '12', 'label': 'Original Tune'},
      ],
    );

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('H12'));
    await tester.pumpAndSettle();

    // Now on the H hymn, whose tune link points back to NT12. The panel
    // stays open across the book switch, so NT12 shows right away.
    expect(find.text('H hymn'), findsOneWidget);
    expect(find.text('NT12'), findsOneWidget);
  });

  testWidgets('version icon hidden when no tune or language links',
      (tester) async {
    await pumpTuneLinkScreen(
      tester,
      bookId: 'nt',
      hymnNumber: 12,
      tuneLinks: null,
    );

    expect(find.byIcon(Icons.swap_horiz), findsNothing);
  });
}
