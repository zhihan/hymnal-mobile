import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'screens/hymn_detail_screen.dart';
import 'services/hymn_db_service.dart';
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
    // For hymns://open/hymn/ts/1, uri.path will be "/open/hymn/ts/1"
    // We need to remove the "/open" prefix to match our router path
    final path = uri.path;

    if (path.isNotEmpty && path != '/') {
      // Remove the "/open" prefix if present
      final routePath = path.startsWith('/open') ? path.substring(5) : path;
      debugPrint('Navigating to: $routePath');
      _router.go(routePath);
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
