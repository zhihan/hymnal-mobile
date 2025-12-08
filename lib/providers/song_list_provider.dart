import 'package:flutter/foundation.dart';
import '../models/song_list.dart';
import '../services/song_list_service.dart';

class SongListProvider extends ChangeNotifier {
  final SongListService _service = SongListService();
  List<SongList> _lists = [];
  bool _isLoaded = false;

  List<SongList> get lists => _lists;
  bool get isLoaded => _isLoaded;

  // Get default Favorites list
  SongList? get defaultList {
    try {
      return _lists.firstWhere((list) => list.isDefault);
    } catch (e) {
      return null;
    }
  }

  // Load all lists
  Future<void> loadLists() async {
    _lists = await _service.getAllLists();
    _isLoaded = true;
    notifyListeners();
  }

  // Create a new list
  Future<SongList?> createList(String name) async {
    try {
      final newList = await _service.createList(name);
      await loadLists();
      return newList;
    } catch (e) {
      return null;
    }
  }

  // Delete a list
  Future<bool> deleteList(String listId) async {
    final success = await _service.deleteList(listId);
    if (success) {
      await loadLists();
    }
    return success;
  }

  // Rename a list
  Future<bool> renameList(String listId, String newName) async {
    final success = await _service.renameList(listId, newName);
    if (success) {
      await loadLists();
    }
    return success;
  }

  // Add hymn to a list
  Future<bool> addHymnToList(String listId, String hymnId) async {
    final success = await _service.addHymnToList(listId, hymnId);
    if (success) {
      await loadLists();
    }
    return success;
  }

  // Remove hymn from a list
  Future<bool> removeHymnFromList(String listId, String hymnId) async {
    final success = await _service.removeHymnFromList(listId, hymnId);
    if (success) {
      await loadLists();
    }
    return success;
  }

  // Toggle hymn in default Favorites list
  Future<bool> toggleFavorite(String hymnId) async {
    final favList = defaultList;
    if (favList == null) return false;

    if (favList.containsHymn(hymnId)) {
      return await removeHymnFromList(favList.id, hymnId);
    } else {
      return await addHymnToList(favList.id, hymnId);
    }
  }

  // Check if hymn is in a specific list
  bool isHymnInList(String listId, String hymnId) {
    try {
      final list = _lists.firstWhere((l) => l.id == listId);
      return list.containsHymn(hymnId);
    } catch (e) {
      return false;
    }
  }

  // Check if hymn is favorited (in default list)
  bool isFavorite(String hymnId) {
    final favList = defaultList;
    if (favList == null) return false;
    return favList.containsHymn(hymnId);
  }

  // Get all lists containing a hymn
  List<SongList> getListsContainingHymn(String hymnId) {
    return _lists.where((list) => list.containsHymn(hymnId)).toList();
  }

  // Get a specific list by ID
  SongList? getListById(String id) {
    try {
      return _lists.firstWhere((list) => list.id == id);
    } catch (e) {
      return null;
    }
  }

  // Reorder hymns in a list
  Future<bool> reorderHymns(String listId, List<String> newOrder) async {
    final success = await _service.reorderHymns(listId, newOrder);
    if (success) {
      await loadLists();
    }
    return success;
  }

  // Export a list
  Future<String?> exportList(String listId) async {
    return await _service.exportList(listId);
  }

  // Import a list
  Future<SongList?> importList(String jsonString) async {
    final importedList = await _service.importList(jsonString);
    if (importedList != null) {
      await loadLists();
    }
    return importedList;
  }
}
