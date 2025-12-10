import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'screens/hymn_detail_screen.dart';
import 'screens/song_list_detail_screen.dart';
import 'services/hymn_db_service.dart';
import 'services/song_list_share_service.dart';
import 'services/song_list_service.dart';
import 'providers/favorites_provider.dart';
import 'providers/song_list_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Isar database
  await HymnDbService.initializeDatabase();

  runApp(const HymnalApp());
}

class HymnalApp extends StatefulWidget {
  const HymnalApp({super.key});

  @override
  State<HymnalApp> createState() => _HymnalAppState();
}

class _HymnalAppState extends State<HymnalApp> {
  late final GoRouter _router;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();

    _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/hymn/:bookId/:number',
          builder: (context, state) {
            final bookId = state.pathParameters['bookId'] ?? 'ts';
            final numberStr = state.pathParameters['number'] ?? '1';
            final number = int.tryParse(numberStr) ?? 1;
            // Use a ValueKey to force widget recreation when parameters change
            return HymnDetailScreen(
              key: ValueKey('${bookId}_$number'),
              initialHymnNumber: number,
              bookId: bookId,
            );
          },
        ),
        GoRoute(
          path: '/songlist/:encodedData',
          builder: (context, state) {
            final encodedData = state.pathParameters['encodedData'] ?? '';
            // Show import confirmation dialog immediately
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showImportDialog(context, encodedData);
            });
            return const HomeScreen();
          },
        ),
      ],
    );

    _initDeepLinks();
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle the initial deep link when the app is launched
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Handle deep links while the app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');

    // Extract the path from the URI
    // For https://cicmusic.net/hymn/ts/1, uri.path will be "/hymn/ts/1"
    final path = uri.path;

    if (path.isNotEmpty && path != '/') {
      debugPrint('Navigating to: $path');
      _router.go(path);
    }
  }

  void _showImportDialog(BuildContext context, String encodedData) {
    if (encodedData.isEmpty) {
      return;
    }

    try {
      // Decode the song list data
      final data = SongListShareService.decodeSongListData(encodedData);
      final name = data['name'] as String;
      final hymnIds = data['hymnIds'] as List<String>;

      // Validate hymn IDs
      if (!SongListShareService.validateHymnIds(hymnIds)) {
        _showErrorDialog(context, 'Invalid hymn IDs in song list');
        return;
      }

      // Show confirmation dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import Song List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Do you want to import this song list?'),
              const SizedBox(height: 16),
              Text(
                'Name: $name',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Hymns: ${hymnIds.length}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _router.go('/'); // Navigate back to home
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _importSongList(context, name, hymnIds);
              },
              child: const Text('Import'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error decoding song list: $e');
      _showErrorDialog(context, 'Invalid or corrupted song list link');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _router.go('/');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _importSongList(
    BuildContext context,
    String name,
    List<String> hymnIds,
  ) async {
    try {
      final songListService = SongListService();
      final existingLists = await songListService.getAllLists();

      // Generate unique name
      final uniqueName = SongListShareService.generateUniqueName(
        name,
        existingLists,
      );

      // Import the song list with all hymns in one operation
      final newList = await songListService.importList(uniqueName, hymnIds);

      // Reload lists in provider
      if (context.mounted) {
        final provider = Provider.of<SongListProvider>(context, listen: false);
        await provider.loadLists();

        // Navigate to the imported list
        _router.go('/');

        // Show success message after navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Imported: $uniqueName'),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongListDetailScreen(listId: newList.id),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error importing song list: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import song list: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => FavoritesProvider()..loadFavorites(),
        ),
        ChangeNotifierProvider(
          create: (context) => SongListProvider()..loadLists(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Hymnal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}
