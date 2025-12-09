import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/hymn_db_service.dart';
import 'providers/favorites_provider.dart';
import 'providers/song_list_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Isar database
  await HymnDbService.initializeDatabase();

  runApp(const HymnalApp());
}

class HymnalApp extends StatelessWidget {
  const HymnalApp({super.key});

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
      child: MaterialApp(
        title: 'Hymnal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
