import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hymn_db.dart';

/// Service for building the Isar database from JSON files
/// Run this to generate the pre-built database file
class DbBuilder {
  static Future<String> buildAndExportDatabase() async {
    print('\n=== Building Isar Database ===\n');

    // Load available hymns
    final availableHymnsJson = await rootBundle.loadString('assets/available_hymns.json');
    final Map<String, dynamic> availableHymns = json.decode(availableHymnsJson);

    // Get temp directory
    final tempDir = await getTemporaryDirectory();
    final buildPath = '${tempDir.path}/db_build';
    final buildDir = Directory(buildPath);
    if (buildDir.existsSync()) {
      buildDir.deleteSync(recursive: true);
    }
    buildDir.createSync(recursive: true);

    print('Building database at: $buildPath');

    // Open Isar instance
    final isar = await Isar.open(
      [HymnDbSchema],
      directory: buildPath,
      name: 'hymns',
    );

    int totalProcessed = 0;
    int totalCount = 0;

    // Count total hymns
    for (final entry in availableHymns.entries) {
      totalCount += (entry.value as List).length;
    }

    print('Total hymns to process: $totalCount\n');

    await isar.writeTxn(() async {
      for (final entry in availableHymns.entries) {
        final category = entry.key;
        final hymnNumbers = (entry.value as List).cast<int>();

        print('Processing category: $category (${hymnNumbers.length} hymns)');

        for (final number in hymnNumbers) {
          try {
            final content = await rootBundle.loadString('hymns/${category}_$number.json');
            final jsonData = json.decode(content) as Map<String, dynamic>;

            final fileName = '${category}_$number';
            final hymnDb = HymnDb.fromJson(fileName, jsonData);

            await isar.hymnDbs.put(hymnDb);
            totalProcessed++;

            if (totalProcessed % 100 == 0) {
              print('  Progress: $totalProcessed/$totalCount');
            }
          } catch (e) {
            print('  Error loading ${category}_$number: $e');
          }
        }
      }
    });

    await isar.close();

    print('\n✅ Database build complete!');
    print('   Total hymns: $totalProcessed');

    // Copy to project assets/db directory
    final projectDbPath = Directory.current.path + '/assets/db';
    final projectDbDir = Directory(projectDbPath);
    if (!projectDbDir.existsSync()) {
      projectDbDir.createSync(recursive: true);
    }

    // Copy all hymns.isar* files
    print('\nCopying database files...');
    final files = buildDir.listSync();
    for (final file in files) {
      if (file is File && file.path.contains('hymns')) {
        final fileName = file.path.split('/').last;
        final destPath = '$projectDbPath/$fileName';
        await file.copy(destPath);
        print('  Copied: $fileName');
      }
    }

    // Calculate size
    final dbFile = File('$projectDbPath/hymns.isar');
    if (dbFile.existsSync()) {
      final size = dbFile.lengthSync();
      print('\n📊 Database size: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
    }

    print('\n✅ Database exported to: $projectDbPath');
    print('\nNext steps:');
    print('  1. Update pubspec.yaml to include assets/db/');
    print('  2. Update pubspec.yaml to exclude hymns/');
    print('  3. Update HymnDbService to copy from assets');

    return projectDbPath;
  }
}
