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
  static const List<String> _ypSongbookHymns = [
    'ns_375',
    'ns_638',
    'ns_192',
    "h_1086",
    "ns_74",
    "ns_634",
    "ns_626",
    "ns_952",
    "ns_131",
    "ns_58",
    "ns_120",
    "lb_70",
    "ns_530",
    "ns_777",
    "ns_465",
    "ns_105",
    "ns_506",
    //
    "ns_820",
    "ns_670",
    "ns_666",
    "ns_620",
    // "ns_1108",
    "ns_352",
    "ns_617",
    // songbase
    "lb_41",
    "ns_541",
    "ns_714",
    "ns_28",
    "ns_149",
    "ns_102",
    "ns_381",
    "ns_391",
    "ns_453",
    "ns_728",
    "ns_283",
    "ns_709",
    "ns_190",
    // c_93
    "ns_347",
    "ns_199",
    "ns_720",
    "ns_712",
    "ns_435",
    "ns_53",
    "ns_771",
    "ns_98",
    "ns_259",
    "ns_172",
    // h/1340
    // h/1341
    "ns_748",
    "ns_292",
    "ns_302",
    "lb_66",
    "ns_915",
    "lb_76",
    "lb_52",
    "ns_202",
    "ns_116",
    "ns_971",
    "ns_731",
    "lb_14",
    "ns_301",
    "ns_970",
    "ns_757",
    "ns_916",
    "ns_48",
    // nt/1048
    "ns_78",
    "h_1248",
    "ns_707",
    "ns_285",
    // nt/547
    "ns_783",
    "ns_286",
    // nt/720
    "ns_639",
    // nt/252
    "ns_287",
    // nt/33
    "ns_419",
    "ns_739",
    "ns_812",
    "ns_975",
    "ns_279",
    "ns_897",
    "ns_972",
    "ns_973",
    "ns_723",
    "ns_938",
    "ns_784",
    "ns_928",
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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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

    lists[index] = updatedList.copyWith(updatedAt: DateTime.now());
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

  // Export a list to JSON string
  Future<String?> exportList(String listId) async {
    final list = await getListById(listId);
    if (list == null) return null;

    final exportData = {
      'version': '1.0',
      'list': list.toJson(),
    };

    return jsonEncode(exportData);
  }

  // Import a list from JSON string
  Future<SongList?> importList(String jsonString) async {
    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);

      // Validate version
      if (decoded['version'] != '1.0') {
        throw Exception('Unsupported version');
      }

      final listData = decoded['list'] as Map<String, dynamic>;
      final importedList = SongList.fromJson(listData);

      // Validate hymn count
      if (importedList.hymnIds.length > SongList.maxHymnsPerList) {
        throw Exception('List exceeds maximum hymn limit');
      }

      // Generate new ID to avoid conflicts
      final newList = importedList.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDefault: false, // Imported lists are never default
      );

      final prefs = await SharedPreferences.getInstance();
      final lists = await getAllLists();
      lists.add(newList);
      await _saveLists(prefs, lists);

      return newList;
    } catch (e) {
      return null;
    }
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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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
      // No lists yet, create YP Songbook along with default list
      final ypSongbook = SongList(
        id: _ypSongbookId,
        name: 'YP Songbook',
        hymnIds: List.from(_ypSongbookHymns),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDefault: false,
        isBuiltIn: true,
      );
      await _saveLists(prefs, [ypSongbook]);
      await prefs.setBool(_builtInListsInitializedKey, true);
      return;
    }

    try {
      final List<dynamic> decoded = jsonDecode(listsJson);
      final lists = decoded.map((json) => SongList.fromJson(json as Map<String, dynamic>)).toList();

      // Create YP Songbook if it doesn't exist
      final hasYpSongbook = lists.any((list) => list.id == _ypSongbookId);
      if (!hasYpSongbook) {
        final ypSongbook = SongList(
          id: _ypSongbookId,
          name: 'YP Songbook',
          hymnIds: List.from(_ypSongbookHymns),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isDefault: false,
          isBuiltIn: true,
        );
        lists.add(ypSongbook);
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
      // Check if hymns list has changed
      final currentHymns = currentYp.hymnIds.toSet();
      final newHymns = _ypSongbookHymns.toSet();

      if (!currentHymns.containsAll(newHymns) || !newHymns.containsAll(currentHymns)) {
        // Update the list with new hymns
        lists[ypIndex] = currentYp.copyWith(
          hymnIds: List.from(_ypSongbookHymns),
          updatedAt: DateTime.now(),
        );
        updated = true;
      }
    } else {
      // YP Songbook doesn't exist, create it
      final ypSongbook = SongList(
        id: _ypSongbookId,
        name: 'YP Songbook',
        hymnIds: List.from(_ypSongbookHymns),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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
