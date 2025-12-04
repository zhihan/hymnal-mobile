import 'package:flutter/foundation.dart';
import '../services/favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoritesService _favoritesService = FavoritesService();
  List<String> _favorites = [];
  bool _isLoaded = false;

  List<String> get favorites => _favorites;
  bool get isLoaded => _isLoaded;

  Future<void> loadFavorites() async {
    _favorites = await _favoritesService.getFavorites();
    _isLoaded = true;
    notifyListeners();
  }

  bool isFavorite(String hymnId) {
    return _favorites.contains(hymnId);
  }

  Future<void> toggleFavorite(String hymnId) async {
    await _favoritesService.toggleFavorite(hymnId);
    await loadFavorites();
  }

  Future<void> addFavorite(String hymnId) async {
    await _favoritesService.addFavorite(hymnId);
    await loadFavorites();
  }

  Future<void> removeFavorite(String hymnId) async {
    await _favoritesService.removeFavorite(hymnId);
    await loadFavorites();
  }
}
