import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymns_mobile/services/song_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Expected YP Songbook content: packet songs 1-105 in packet order,
// all linked to songbase records (sb_*, plus h_* for songbase's
// english_hymnal book). Songs 12/92 and 31/94 are repeats in the packet.
const _expectedYpSongbookHymns = [
  'sb_363', // 1
  'sb_2354', // 2
  'sb_3452', // 3
  'sb_733', // 4
  'h_1086', // 5
  'sb_557', // 6
  'sb_296', // 7
  'sb_3455', // 8
  'sb_375', // 9
  'sb_532', // 10
  'sb_669', // 11
  'sb_680', // 12
  'sb_577', // 13
  'sb_276', // 14
  'sb_3351', // 15
  'sb_270', // 16
  'sb_319', // 17
  'sb_2336', // 18
  'sb_396', // 19
  'sb_3424', // 20
  'sb_6196', // 21
  'sb_3423', // 22
  'sb_962', // 23
  'sb_920', // 24
  'sb_491', // 25
  'sb_268', // 26
  'sb_3589', // 27
  'sb_571', // 28
  'sb_2360', // 29
  'sb_3436', // 30
  'sb_750', // 31
  'sb_3415', // 32
  'sb_704', // 33
  'sb_339', // 34
  'sb_911', // 35
  'sb_952', // 36
  'sb_2191', // 37
  'sb_2314', // 38
  'sb_658', // 39
  'sb_770', // 40
  'sb_593', // 41
  'sb_647', // 42
  'sb_3517', // 43
  'sb_623', // 44
  'sb_2322', // 45
  'sb_2346', // 46
  'sb_99', // 47
  'sb_628', // 48
  'sb_517', // 49
  'sb_3432', // 50
  'sb_3434', // 51
  'sb_723', // 52
  'sb_662', // 53
  'h_327', // 54
  'sb_330', // 55
  'h_1340', // 56
  'h_1341', // 57
  'sb_7031', // 58
  'sb_10000', // 59
  'sb_3435', // 60
  'sb_469', // 61
  'sb_615', // 62
  'sb_349', // 63
  'sb_3946', // 64
  'sb_348', // 65
  'sb_456', // 66
  'sb_3487', // 67
  'sb_471', // 68
  'sb_4415', // 69
  'sb_3629', // 70
  'sb_497', // 71
  'sb_587', // 72
  'sb_4414', // 73
  'sb_3459', // 74
  'sb_4420', // 75
  'sb_661', // 76
  'sb_405', // 77
  'h_1048', // 78
  'sb_427', // 79
  'h_1248', // 80
  'sb_905', // 81
  'sb_401', // 82
  'sb_803', // 83
  'h_547', // 84
  'sb_6004', // 85
  'sb_634', // 86
  'h_720', // 87
  'sb_3499', // 88
  'h_252', // 89
  'sb_512', // 90
  'h_33', // 91
  'sb_680', // 92
  'sb_3518', // 93
  'sb_750', // 94
  'sb_3416', // 95
  'sb_4015', // 96
  'sb_4416', // 97
  'sb_4421', // 98
  'sb_10329', // 99
  'sb_4412', // 100
  'sb_4413', // 101
  'sb_3353', // 102
  'sb_3346', // 103
  'sb_4462', // 104
  'sb_2164', // 105
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YP Songbook built-in list', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('is created with the 105 packet songs in packet order', () async {
      final service = SongListService();
      final lists = await service.getAllLists();

      final yp = lists.firstWhere(
        (list) => list.id == 'built_in_yp_songbook',
        orElse: () => throw StateError('YP Songbook not found'),
      );

      expect(yp.name, equals('YP Songbook'));
      expect(yp.isBuiltIn, isTrue);
      expect(yp.hymnIds, orderedEquals(_expectedYpSongbookHymns));
    });

    test('every hymn id is within the crawler\'s coverage', () async {
      // assets/available_hymns.json is a gitignored build artifact, so this
      // test validates against the crawler's known ranges instead (see
      // crawler/crawl_hymns.py CATEGORY_RANGES). sb_* ids are covered by the
      // songbase crawl as long as they are not in songbase's english_hymnal
      // set (verified during song lookup).
      const ranges = {
        'ch': 800,
        'ts': 1000,
        'h': 1400,
        'ns': 1200,
        'lb': 100,
        'nt': 1400,
      };
      final bad = <String>[];
      for (final id in _expectedYpSongbookHymns) {
        final parts = id.split('_');
        if (parts.length != 2) {
          bad.add(id);
          continue;
        }
        final num = int.tryParse(parts[1]);
        if (parts[0] == 'sb') {
          if (num == null || num <= 0) bad.add(id);
        } else if (!ranges.containsKey(parts[0]) ||
            num == null ||
            num < 1 ||
            num > ranges[parts[0]]!) {
          bad.add(id);
        }
      }
      expect(bad, isEmpty,
          reason: 'YP song ids outside crawler coverage: $bad');
    });

    test('refreshes a stale built-in list to the new content and order',
        () async {
      // Seed prefs with an outdated YP Songbook (old content and order).
      final staleYp = {
        'id': 'built_in_yp_songbook',
        'name': 'YP Songbook',
        'hymnIds': ['ns_375', 'ns_638', 'ns_192'],
        'isDefault': false,
        'isBuiltIn': true,
      };
      SharedPreferences.setMockInitialValues({
        'song_lists': json.encode([staleYp]),
        'built_in_lists_initialized': true,
      });

      final service = SongListService();
      final lists = await service.getAllLists();
      final yp = lists.firstWhere((list) => list.id == 'built_in_yp_songbook');

      expect(yp.hymnIds, orderedEquals(_expectedYpSongbookHymns));
    });

    test('does not rewrite the list when it already matches', () async {
      final freshYp = {
        'id': 'built_in_yp_songbook',
        'name': 'YP Songbook',
        'hymnIds': _expectedYpSongbookHymns,
        'isDefault': false,
        'isBuiltIn': true,
      };
      SharedPreferences.setMockInitialValues({
        'song_lists': json.encode([freshYp]),
        'built_in_lists_initialized': true,
      });

      final service = SongListService();
      final lists = await service.getAllLists();
      final yp = lists.firstWhere((list) => list.id == 'built_in_yp_songbook');

      // Still correct, and no duplicate lists created.
      expect(yp.hymnIds, orderedEquals(_expectedYpSongbookHymns));
      expect(
        lists.where((list) => list.id == 'built_in_yp_songbook'),
        hasLength(1),
      );
    });
  });
}
