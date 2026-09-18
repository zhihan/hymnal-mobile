import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/song_list.dart';

class SongListService {
  static const String _songListsKey = 'song_lists';
  static const String _oldFavoritesKey = 'favorite_hymns';
  static const String _migrationCompleteKey = 'song_lists_migration_complete';
  static const String _builtInListsInitializedKey = 'built_in_lists_initialized';
  static const String _defaultListName = 'Favorites';

  // Built-in list IDs (fixed, never change these)
  static const String _ypSongbookId = 'built_in_yp_songbook';

  // YP Songbook hymn list - UPDATE THIS ARRAY to modify the list
  // Order follows the YP Song Packet (songs 1-105); trailing comments
  // show the packet song number. Every entry is a songbase record:
  // sb_* are songbase-only songs; h_* are songbase's english_hymnal
  // records (the crawler emits those as h_*, merged with hymnal.net's).
  // Note: the packet itself repeats two hymns (songs 12/92 and 31/94).
  static const List<String> _ypSongbookHymns = [
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

  final _uuid = const Uuid();

  // Get all song lists
  Future<List<SongList>> getAllLists() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if migration is needed
    await _migrateFromOldFavorites(prefs);

    // Initialize built-in lists if needed
    await _initializeBuiltInLists(prefs);

    final listsJson = prefs.getString(_songListsKey);
    if (listsJson == null || listsJson.isEmpty) {
      // Create default Favorites list if none exist
      final defaultList = await _createDefaultList(prefs);
      return [defaultList];
    }

    try {
      final List<dynamic> decoded = jsonDecode(listsJson);
      final lists = decoded.map((json) => SongList.fromJson(json as Map<String, dynamic>)).toList();

      // Ensure there's always a default list (safety check)
      final hasDefaultList = lists.any((list) => list.isDefault);
      if (!hasDefaultList) {
        final defaultList = SongList(
          id: _uuid.v4(),
          name: _defaultListName,
          hymnIds: [],
          isDefault: true,
        );
        lists.insert(0, defaultList);
        await _saveLists(prefs, lists);
      }

      // Always update built-in lists with latest content
      await _updateBuiltInLists(prefs, lists);

      return lists;
    } catch (e) {
      // If parsing fails, return empty list with default
      final defaultList = await _createDefaultList(prefs);
      return [defaultList];
    }
  }

  // Get a specific list by ID
  Future<SongList?> getListById(String id) async {
    final lists = await getAllLists();
    try {
      return lists.firstWhere((list) => list.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get the default Favorites list
  Future<SongList?> getDefaultList() async {
    final lists = await getAllLists();
    try {
      return lists.firstWhere((list) => list.isDefault);
    } catch (e) {
      return null;
    }
  }

  // Create a new song list
  Future<SongList> createList(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final lists = await getAllLists();

    final newList = SongList(
      id: _uuid.v4(),
      name: name,
      hymnIds: [],
      isDefault: false,
    );

    lists.add(newList);
    await _saveLists(prefs, lists);

    return newList;
  }

  // Update an existing list
  Future<bool> updateList(SongList updatedList) async {
    final prefs = await SharedPreferences.getInstance();
    final lists = await getAllLists();

    final index = lists.indexWhere((list) => list.id == updatedList.id);
    if (index == -1) return false;

    lists[index] = updatedList;
    await _saveLists(prefs, lists);

    return true;
  }

  // Delete a list (cannot delete default or built-in lists)
  Future<bool> deleteList(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final lists = await getAllLists();

    final listToDelete = lists.firstWhere(
      (list) => list.id == id,
      orElse: () => throw Exception('List not found'),
    );

    // Cannot delete default or built-in lists
    if (listToDelete.isDefault || listToDelete.isBuiltIn) return false;

    lists.removeWhere((list) => list.id == id);
    await _saveLists(prefs, lists);

    return true;
  }

  // Rename a list
  Future<bool> renameList(String id, String newName) async {
    final list = await getListById(id);
    if (list == null) return false;

    final updatedList = list.copyWith(name: newName);
    return await updateList(updatedList);
  }

  // Add hymn to a list
  Future<bool> addHymnToList(String listId, String hymnId) async {
    final list = await getListById(listId);
    if (list == null) return false;

    // Cannot modify built-in lists
    if (list.isBuiltIn) return false;

    // Check if already in list
    if (list.containsHymn(hymnId)) return true;

    // Check if list is full
    if (list.isFull()) return false;

    final updatedHymnIds = List<String>.from(list.hymnIds)..add(hymnId);
    final updatedList = list.copyWith(hymnIds: updatedHymnIds);

    return await updateList(updatedList);
  }

  // Remove hymn from a list
  Future<bool> removeHymnFromList(String listId, String hymnId) async {
    final list = await getListById(listId);
    if (list == null) return false;

    // Cannot modify built-in lists
    if (list.isBuiltIn) return false;

    final updatedHymnIds = List<String>.from(list.hymnIds)..remove(hymnId);
    final updatedList = list.copyWith(hymnIds: updatedHymnIds);

    return await updateList(updatedList);
  }

  // Reorder hymns in a list
  Future<bool> reorderHymns(String listId, List<String> newOrder) async {
    final list = await getListById(listId);
    if (list == null) return false;

    // Cannot modify built-in lists
    if (list.isBuiltIn) return false;

    // Validate that all hymns in newOrder are in the original list
    if (newOrder.length != list.hymnIds.length) return false;
    if (!newOrder.every((id) => list.hymnIds.contains(id))) return false;

    final updatedList = list.copyWith(hymnIds: newOrder);
    return await updateList(updatedList);
  }

  // Check if a hymn is in a specific list
  Future<bool> isHymnInList(String listId, String hymnId) async {
    final list = await getListById(listId);
    if (list == null) return false;
    return list.containsHymn(hymnId);
  }

  // Get all lists containing a specific hymn
  Future<List<SongList>> getListsContainingHymn(String hymnId) async {
    final lists = await getAllLists();
    return lists.where((list) => list.containsHymn(hymnId)).toList();
  }

  // Import a song list with hymns (for sharing feature)
  Future<SongList> importList(String name, List<String> hymnIds) async {
    final prefs = await SharedPreferences.getInstance();
    final lists = await getAllLists();

    final newList = SongList(
      id: _uuid.v4(),
      name: name,
      hymnIds: hymnIds,
      isDefault: false,
      isBuiltIn: false,
    );

    lists.add(newList);
    await _saveLists(prefs, lists);

    return newList;
  }

  // Private helper: Save lists to SharedPreferences
  Future<void> _saveLists(SharedPreferences prefs, List<SongList> lists) async {
    final jsonString = jsonEncode(lists.map((list) => list.toJson()).toList());
    await prefs.setString(_songListsKey, jsonString);
  }

  // Private helper: Create default Favorites list
  Future<SongList> _createDefaultList(SharedPreferences prefs) async {
    final defaultList = SongList(
      id: _uuid.v4(),
      name: _defaultListName,
      hymnIds: [],
      isDefault: true,
    );

    await _saveLists(prefs, [defaultList]);
    return defaultList;
  }

  // Private helper: Migrate from old favorites system
  Future<void> _migrateFromOldFavorites(SharedPreferences prefs) async {
    // Check if migration already completed
    final migrationComplete = prefs.getBool(_migrationCompleteKey) ?? false;
    if (migrationComplete) return;

    // Check if new system already has data
    final existingLists = prefs.getString(_songListsKey);
    if (existingLists != null && existingLists.isNotEmpty) {
      await prefs.setBool(_migrationCompleteKey, true);
      return;
    }

    // Check for old favorites
    final oldFavorites = prefs.getStringList(_oldFavoritesKey);
    if (oldFavorites == null || oldFavorites.isEmpty) {
      // No old favorites to migrate
      await prefs.setBool(_migrationCompleteKey, true);
      return;
    }

    // Create default list with old favorites
    final defaultList = SongList(
      id: _uuid.v4(),
      name: _defaultListName,
      hymnIds: oldFavorites,
      isDefault: true,
    );

    await _saveLists(prefs, [defaultList]);

    // Mark migration as complete (but keep old data for safety)
    await prefs.setBool(_migrationCompleteKey, true);
  }

  // Private helper: Initialize built-in lists on first run
  Future<void> _initializeBuiltInLists(SharedPreferences prefs) async {
    // Check if built-in lists already initialized
    final initialized = prefs.getBool(_builtInListsInitializedKey) ?? false;
    if (initialized) return;

    final listsJson = prefs.getString(_songListsKey);
    if (listsJson == null || listsJson.isEmpty) {
      // No lists yet, create both default Favorites list and YP Songbook
      final defaultList = SongList(
        id: _uuid.v4(),
        name: _defaultListName,
        hymnIds: [],
        isDefault: true,
      );
      final ypSongbook = SongList(
        id: _ypSongbookId,
        name: 'YP Songbook',
        hymnIds: List.from(_ypSongbookHymns),
        isDefault: false,
        isBuiltIn: true,
      );
      await _saveLists(prefs, [defaultList, ypSongbook]);
      await prefs.setBool(_builtInListsInitializedKey, true);
      return;
    }

    try {
      final List<dynamic> decoded = jsonDecode(listsJson);
      final lists = decoded.map((json) => SongList.fromJson(json as Map<String, dynamic>)).toList();

      bool needsSave = false;

      // Create default Favorites list if it doesn't exist
      final hasDefaultList = lists.any((list) => list.isDefault);
      if (!hasDefaultList) {
        final defaultList = SongList(
          id: _uuid.v4(),
          name: _defaultListName,
          hymnIds: [],
          isDefault: true,
        );
        lists.insert(0, defaultList); // Insert at beginning so it appears first
        needsSave = true;
      }

      // Create YP Songbook if it doesn't exist
      final hasYpSongbook = lists.any((list) => list.id == _ypSongbookId);
      if (!hasYpSongbook) {
        final ypSongbook = SongList(
          id: _ypSongbookId,
          name: 'YP Songbook',
          hymnIds: List.from(_ypSongbookHymns),
          isDefault: false,
          isBuiltIn: true,
        );
        lists.add(ypSongbook);
        needsSave = true;
      }

      if (needsSave) {
        await _saveLists(prefs, lists);
      }

      await prefs.setBool(_builtInListsInitializedKey, true);
    } catch (e) {
      // If parsing fails, mark as initialized anyway to avoid retry loops
      await prefs.setBool(_builtInListsInitializedKey, true);
    }
  }

  // Private helper: Update built-in lists with latest content from code
  Future<void> _updateBuiltInLists(SharedPreferences prefs, List<SongList> lists) async {
    bool updated = false;

    // Update or create YP Songbook
    final ypIndex = lists.indexWhere((list) => list.id == _ypSongbookId);
    if (ypIndex != -1) {
      final currentYp = lists[ypIndex];
      // Refresh when content or order differs from the built-in list
      final currentHymns = currentYp.hymnIds;
      final needsUpdate = currentHymns.length != _ypSongbookHymns.length ||
          !Iterable.generate(_ypSongbookHymns.length)
              .every((i) => currentHymns[i] == _ypSongbookHymns[i]);

      if (needsUpdate) {
        // Update the list with new hymns
        lists[ypIndex] = currentYp.copyWith(
          hymnIds: List.from(_ypSongbookHymns),
        );
        updated = true;
      }
    } else {
      // YP Songbook doesn't exist, create it
      final ypSongbook = SongList(
        id: _ypSongbookId,
        name: 'YP Songbook',
        hymnIds: List.from(_ypSongbookHymns),
        isDefault: false,
        isBuiltIn: true,
      );
      lists.add(ypSongbook);
      updated = true;
    }

    if (updated) {
      await _saveLists(prefs, lists);
    }
  }
}
