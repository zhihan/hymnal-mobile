import 'dart:convert';
import 'dart:io';

/// Pre-build script that generates the Isar database and available_hymns.json
///
/// This script must be run with Flutter: flutter pub run tool/build_isar_db.dart
///
/// It will:
/// 1. Create a temporary Flutter app that builds the database
/// 2. Copy the database file to assets/db/
/// 3. Generate available_hymns.json
Future<void> main() async {
  print('=== Isar Database Pre-Build Process ===\n');

  // Step 1: Generate available_hymns.json
  print('Step 1: Generating available_hymns.json...');
  await generateAvailableHymns();

  // Step 2: Create database builder script
  print('\nStep 2: Creating database builder...');
  await createDatabaseBuilder();

  // Step 3: Run the builder to generate the database
  print('\nStep 3: Building Isar database...');
  await buildDatabase();

  print('\n=== Build Complete ===');
  print('✅ Database file: assets/db/hymns.isar');
  print('✅ Index file: assets/available_hymns.json');
  print('\nYou can now build your Flutter app with:');
  print('  flutter build ios');
  print('  flutter build apk');
}

Future<void> generateAvailableHymns() async {
  final categories = ['h', 'ch', 'ts', 'c', 'ns', 'nt', 'lb', 'de', 'tagalog', 'children'];
  final Map<String, List<int>> availableHymns = {};

  int totalFound = 0;

  for (final category in categories) {
    final categoryHymns = <int>[];

    for (int i = 1; i <= 1500; i++) {
      final file = File('hymns/${category}_$i.json');
      if (file.existsSync()) {
        categoryHymns.add(i);
        totalFound++;
      }
    }

    if (categoryHymns.isNotEmpty) {
      availableHymns[category] = categoryHymns;
      print('  Found ${categoryHymns.length} hymns in $category');
    }
  }

  // Create assets directory
  final assetsDir = Directory('assets');
  if (!assetsDir.existsSync()) {
    assetsDir.createSync(recursive: true);
  }

  // Write available_hymns.json
  final file = File('assets/available_hymns.json');
  await file.writeAsString(json.encode(availableHymns));

  print('  Total: $totalFound hymns');
}

Future<void> createDatabaseBuilder() async {
  final builderDir = Directory('tool/db_builder');
  if (builderDir.existsSync()) {
    builderDir.deleteSync(recursive: true);
  }
  builderDir.createSync(recursive: true);

  // Create a minimal Flutter app that builds the database
  final builderScript = '''
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../lib/models/hymn_db.dart';

void main() {
  runApp(const DatabaseBuilderApp());
}

class DatabaseBuilderApp extends StatelessWidget {
  const DatabaseBuilderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: DatabaseBuilder(),
        ),
      ),
    );
  }
}

class DatabaseBuilder extends StatefulWidget {
  const DatabaseBuilder({Key? key}) : super(key: key);

  @override
  State<DatabaseBuilder> createState() => _DatabaseBuilderState();
}

class _DatabaseBuilderState extends State<DatabaseBuilder> {
  String status = 'Initializing...';
  bool isComplete = false;

  @override
  void initState() {
    super.initState();
    buildDatabase();
  }

  Future<void> buildDatabase() async {
    try {
      setState(() => status = 'Loading available hymns...');

      // Load available hymns
      final availableHymnsJson = await rootBundle.loadString('assets/available_hymns.json');
      final Map<String, dynamic> availableHymns = json.decode(availableHymnsJson);

      setState(() => status = 'Creating database...');

      // Create database in temp directory
      final tempDir = await getTemporaryDirectory();
      final dbPath = '\${tempDir.path}/db_build';
      final dbDir = Directory(dbPath);
      if (dbDir.existsSync()) {
        dbDir.deleteSync(recursive: true);
      }
      dbDir.createSync(recursive: true);

      final isar = await Isar.open(
        [HymnDbSchema],
        directory: dbPath,
        name: 'hymns',
      );

      setState(() => status = 'Populating database...');

      int count = 0;
      int total = 0;

      for (final entry in availableHymns.entries) {
        total += (entry.value as List).length;
      }

      await isar.writeTxn(() async {
        for (final entry in availableHymns.entries) {
          final category = entry.key;
          final hymnNumbers = (entry.value as List).cast<int>();

          for (final number in hymnNumbers) {
            try {
              final content = await rootBundle.loadString('hymns/\${category}_\$number.json');
              final jsonData = json.decode(content) as Map<String, dynamic>;
              final fileName = '\${category}_\$number';
              final hymnDb = HymnDb.fromJson(fileName, jsonData);
              await isar.hymnDbs.put(hymnDb);

              count++;
              if (count % 100 == 0) {
                setState(() => status = 'Loaded \$count/\$total hymns...');
              }
            } catch (e) {
              print('Error loading \${category}_\$number: \$e');
            }
          }
        }
      });

      await isar.close();

      setState(() => status = 'Copying database files...');

      // Copy database files to assets/db/
      final projectDir = Directory.current;
      final assetsDbDir = Directory('\${projectDir.path}/assets/db');
      if (!assetsDbDir.existsSync()) {
        assetsDbDir.createSync(recursive: true);
      }

      // Copy all hymns.isar* files
      final files = dbDir.listSync();
      for (final file in files) {
        if (file is File && file.path.contains('hymns')) {
          final fileName = file.path.split('/').last;
          final destPath = '\${assetsDbDir.path}/\$fileName';
          await file.copy(destPath);
          print('Copied: \$fileName');
        }
      }

      final dbFile = File('\${assetsDbDir.path}/hymns.isar');
      if (dbFile.existsSync()) {
        final size = dbFile.lengthSync();
        print('Database size: \${(size / 1024 / 1024).toStringAsFixed(2)} MB');
      }

      setState(() {
        status = 'Complete! \$count hymns loaded.';
        isComplete = true;
      });

      // Exit after a short delay
      await Future.delayed(const Duration(seconds: 2));
      exit(0);

    } catch (e, stack) {
      setState(() => status = 'Error: \$e');
      print('Error: \$e');
      print('Stack: \$stack');
      await Future.delayed(const Duration(seconds: 5));
      exit(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isComplete)
          const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(
          status,
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
''';

  final builderFile = File('tool/db_builder/main.dart');
  await builderFile.writeAsString(builderScript);

  print('  Created: tool/db_builder/main.dart');
}

Future<void> buildDatabase() async {
  print('  Running Flutter database builder...');
  print('  This will open a window and build the database...\n');

  final result = await Process.run(
    'flutter',
    ['run', '-d', 'macos', 'tool/db_builder/main.dart'],
    runInShell: true,
  );

  if (result.exitCode == 0) {
    print('\n  ✅ Database built successfully');
  } else {
    print('\n  ❌ Database build failed');
    print('  stdout: ${result.stdout}');
    print('  stderr: ${result.stderr}');
    exit(1);
  }
}
