import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/hymn_db_service.dart';

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
    return MaterialApp(
      title: '补充本',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
