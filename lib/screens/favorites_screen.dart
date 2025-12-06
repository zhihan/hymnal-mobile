import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../services/hymn_db_service.dart';
import '../services/hymn_loader_service.dart';
import '../models/hymn_db.dart';
import 'hymn_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<HymnDb> _favoriteHymns = [];
  bool _isLoading = true;
  Map<String, String> _categories = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadFavoriteHymns();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await HymnLoaderService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      // Keep empty map if loading fails
    }
  }

  Future<void> _loadFavoriteHymns() async {
    setState(() {
      _isLoading = true;
    });

    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);

    // Ensure favorites are loaded from SharedPreferences
    if (!favoritesProvider.isLoaded) {
      await favoritesProvider.loadFavorites();
    }

    final favoriteIds = favoritesProvider.favorites;

    final hymns = <HymnDb>[];
    for (final hymnId in favoriteIds) {
      final hymn = await HymnDbService.getHymnById(hymnId);
      if (hymn != null) {
        hymns.add(hymn);
      }
    }

    setState(() {
      _favoriteHymns = hymns;
      _isLoading = false;
    });
  }

  void _navigateToHymn(HymnDb hymn) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HymnDetailScreen(
          initialHymnNumber: hymn.number,
          bookId: hymn.bookId,
        ),
      ),
    ).then((_) {
      _loadFavoriteHymns();
    });
  }

  String _getDisplayName(HymnDb hymn) {
    final bookName = _categories[hymn.bookId] ?? hymn.bookId.toUpperCase();
    return '$bookName ${hymn.number}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Favorites'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_favoriteHymns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No favorites yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the heart icon on any hymn to add it to your favorites',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        return ListView.builder(
          itemCount: _favoriteHymns.length,
          itemBuilder: (context, index) {
            final hymn = _favoriteHymns[index];
            final isFavorite = favoritesProvider.isFavorite(hymn.hymnId);

            return Dismissible(
              key: Key(hymn.hymnId),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16.0),
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              onDismissed: (direction) {
                favoritesProvider.removeFavorite(hymn.hymnId);
                setState(() {
                  _favoriteHymns.removeAt(index);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${hymn.title} removed from favorites'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        favoritesProvider.addFavorite(hymn.hymnId);
                        _loadFavoriteHymns();
                      },
                    ),
                  ),
                );
              },
              child: ListTile(
                leading: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                title: Text(
                  hymn.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _getDisplayName(hymn),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _navigateToHymn(hymn),
              ),
            );
          },
        );
      },
    );
  }
}
