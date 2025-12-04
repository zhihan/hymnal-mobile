import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorite_hymns';

  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  Future<bool> isFavorite(String hymnId) async {
    final favorites = await getFavorites();
    return favorites.contains(hymnId);
  }

  Future<void> addFavorite(String hymnId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    if (!favorites.contains(hymnId)) {
      favorites.add(hymnId);
      await prefs.setStringList(_favoritesKey, favorites);
    }
  }

  Future<void> removeFavorite(String hymnId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    favorites.remove(hymnId);
    await prefs.setStringList(_favoritesKey, favorites);
  }

  Future<void> toggleFavorite(String hymnId) async {
    if (await isFavorite(hymnId)) {
      await removeFavorite(hymnId);
    } else {
      await addFavorite(hymnId);
    }
  }
}
