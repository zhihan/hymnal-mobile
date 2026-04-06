import 'dart:convert';
import 'dart:io';

/// This script generates the available_hymns.json file by scanning the hymns directory.
/// The Isar database will be built at runtime on first app launch and then cached.
Future<void> main() async {
  print('Starting build process...');

  // Create assets directory if it doesn't exist
  final assetsDir = Directory('assets');
  if (!assetsDir.existsSync()) {
    assetsDir.createSync(recursive: true);
  }

  // Categories to process by range scan (small, dense number ranges)
  final rangeCategories = ['h', 'ch', 'ts', 'c', 'ns', 'nt', 'lb', 'de', 'tagalog', 'children'];

  // Categories to process by directory listing (sparse IDs, e.g., songbase IDs)
  final listCategories = ['sb'];

  // Map to store available hymns by category
  final Map<String, List<int>> availableHymns = {};

  int totalFound = 0;

  // Range-scanned categories
  for (final category in rangeCategories) {
    print('Scanning category: $category');
    final categoryHymns = <int>[];

    for (int i = 1; i <= 9999; i++) {
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

  // Directory-listed categories (for sparse ID ranges)
  final hymnsDir = Directory('hymns');
  if (hymnsDir.existsSync()) {
    for (final category in listCategories) {
      print('Scanning category: $category');
      final categoryHymns = <int>[];
      final prefix = '${category}_';

      for (final entity in hymnsDir.listSync()) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name.startsWith(prefix) && name.endsWith('.json')) {
            final numStr = name.substring(prefix.length, name.length - 5);
            final num = int.tryParse(numStr);
            if (num != null) {
              categoryHymns.add(num);
              totalFound++;
            }
          }
        }
      }

      if (categoryHymns.isNotEmpty) {
        categoryHymns.sort();
        availableHymns[category] = categoryHymns;
        print('  Found ${categoryHymns.length} hymns in $category');
      }
    }
  }

  // Generate available_hymns.json
  final availableHymnsFile = File('assets/available_hymns.json');
  final availableHymnsJson = json.encode(availableHymns);
  await availableHymnsFile.writeAsString(availableHymnsJson);

  print('\n✅ Available hymns file generated!');
  print('   Location: assets/available_hymns.json');
  print('   Total hymns: $totalFound');
  print('   Categories: ${availableHymns.keys.join(', ')}');
}
