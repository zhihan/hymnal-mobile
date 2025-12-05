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

  // Categories to process
  final categories = ['h', 'ch', 'ts', 'c', 'ns', 'nt', 'lb', 'de', 'tagalog', 'children'];

  // Map to store available hymns by category
  final Map<String, List<int>> availableHymns = {};

  int totalFound = 0;

  for (final category in categories) {
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

  // Generate available_hymns.json
  final availableHymnsFile = File('assets/available_hymns.json');
  final availableHymnsJson = json.encode(availableHymns);
  await availableHymnsFile.writeAsString(availableHymnsJson);

  print('\n✅ Available hymns file generated!');
  print('   Location: assets/available_hymns.json');
  print('   Total hymns: $totalFound');
  print('   Categories: ${availableHymns.keys.join(', ')}');
}
