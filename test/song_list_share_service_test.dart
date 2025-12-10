import 'package:flutter_test/flutter_test.dart';
import 'package:hymns_mobile/services/song_list_share_service.dart';
import 'package:hymns_mobile/models/song_list.dart';

void main() {
  group('SongListShareService', () {
    test('encodes and decodes song list correctly', () {
      // Create a test song list
      final songList = SongList(
        id: 'test-id',
        name: 'My Favorites',
        hymnIds: ['ts_1', 'ch_100', 'h_500', 'ns_50'],
        isDefault: false,
        isBuiltIn: false,
      );

      // Generate share URL
      final url = SongListShareService.generateShareUrl(songList);

      // Verify URL format
      expect(url, startsWith('https://cicmusic.net/songlist/v1:'));

      // Decode the URL
      final decoded = SongListShareService.decodeSongListData(url);

      // Verify decoded data
      expect(decoded['name'], equals('My Favorites'));
      expect(decoded['hymnIds'], equals(['ts_1', 'ch_100', 'h_500', 'ns_50']));
    });

    test('generates unique names correctly', () {
      final existingLists = [
        SongList(
          id: '1',
          name: 'Favorites',
          hymnIds: [],
        ),
        SongList(
          id: '2',
          name: 'Favorites (2)',
          hymnIds: [],
        ),
      ];

      // Test unique name
      final unique1 = SongListShareService.generateUniqueName(
        'My List',
        existingLists,
      );
      expect(unique1, equals('My List'));

      // Test conflicting name
      final unique2 = SongListShareService.generateUniqueName(
        'Favorites',
        existingLists,
      );
      expect(unique2, equals('Favorites (3)'));
    });

    test('validates hymn IDs correctly', () {
      // Valid hymn IDs
      expect(
        SongListShareService.validateHymnIds(['ts_1', 'ch_100', 'h_500']),
        isTrue,
      );

      // Empty list (valid)
      expect(SongListShareService.validateHymnIds([]), isTrue);

      // Invalid format
      expect(
        SongListShareService.validateHymnIds(['invalid', 'ts_1']),
        isFalse,
      );

      // Invalid format (no underscore)
      expect(
        SongListShareService.validateHymnIds(['ts1']),
        isFalse,
      );
    });

    test('handles large song lists', () {
      // Create a list with 100 hymns
      final hymnIds = List.generate(100, (i) => 'ns_${i + 1}');
      final songList = SongList(
        id: 'test-id',
        name: 'Large List',
        hymnIds: hymnIds,
      );

      // Generate and decode
      final url = SongListShareService.generateShareUrl(songList);
      final decoded = SongListShareService.decodeSongListData(url);

      // Verify
      expect(decoded['name'], equals('Large List'));
      expect(decoded['hymnIds'], hasLength(100));
      expect(decoded['hymnIds'], equals(hymnIds));

      // Check URL length is reasonable
      expect(url.length, lessThan(2000)); // Well under typical URL limits
    });

    test('throws error for invalid encoded data', () {
      expect(
        () => SongListShareService.decodeSongListData('invalid-data'),
        throwsFormatException,
      );

      expect(
        () => SongListShareService.decodeSongListData('v1:invalid-base64!!!'),
        throwsFormatException,
      );
    });
  });
}
