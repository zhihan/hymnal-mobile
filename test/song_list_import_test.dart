import 'package:flutter_test/flutter_test.dart';
import 'package:hymns_mobile/services/song_list_service.dart';

void main() {
  test('importList creates list with hymns', () async {
    final service = SongListService();

    // Import a list
    final imported = await service.importList('Test Import', ['ts_1', 'ch_100', 'h_500']);

    // Verify it was created correctly
    expect(imported.name, equals('Test Import'));
    expect(imported.hymnIds, equals(['ts_1', 'ch_100', 'h_500']));
    expect(imported.hymnCount, equals(3));
    expect(imported.isDefault, isFalse);
    expect(imported.isBuiltIn, isFalse);

    // Verify it's in the list of all lists
    final allLists = await service.getAllLists();
    final found = allLists.firstWhere((list) => list.id == imported.id);
    expect(found.name, equals('Test Import'));
    expect(found.hymnIds.length, equals(3));
  });
}
