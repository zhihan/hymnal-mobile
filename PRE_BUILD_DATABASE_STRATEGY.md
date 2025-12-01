# Pre-Build Database Strategy for Hymnal App

## Overview

This document describes how to implement a proper pre-build strategy where the Isar database is generated at build time and bundled with the app, rather than building it at runtime.

## Why Pre-Build?

**Current Problem:**
- App takes 10-15 seconds on first launch to build database from 2648 JSON files
- Ships ~15-20 MB of JSON files in the app bundle
- Poor user experience on first launch

**Solution:**
- Generate database file (`hymns.isar`) during build process
- Ship only the database file (~8-10 MB) instead of JSON files
- App starts instantly with full search functionality

## Implementation Steps

### Step 1: Create Build Script

Create `tool/build_db.sh`:

```bash
#!/bin/bash

set -e

echo "=== Building Isar Database ==="
echo

# Step 1: Generate available_hymns.json
echo "Step 1: Generating available_hymns.json..."
dart run tool/build_database.dart

# Step 2: Build the database using a temporary Flutter app
echo "Step 2: Building database with Flutter..."

# Create a temporary Flutter app that builds the database
TEMP_DIR="tool/temp_db_builder"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copy necessary files
cp -r lib "$TEMP_DIR/"
cp -r hymns "$TEMP_DIR/"
cp -r assets "$TEMP_DIR/"
cp pubspec.yaml "$TEMP_DIR/"

# Create a simple main.dart that builds the database
cat > "$TEMP_DIR/lib/main_builder.dart" << 'EOF'
import 'dart:io';
import 'package:flutter/material.dart';
import 'services/db_builder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await DbBuilder.buildAndExportDatabase();
    print('\n✅ Database built successfully!');
    exit(0);
  } catch (e, stack) {
    print('\n❌ Error building database:');
    print(e);
    print(stack);
    exit(1);
  }
}
EOF

# Run the builder
cd "$TEMP_DIR"
flutter pub get
flutter run -d macos lib/main_builder.dart --release

cd ../..

# Step 3: Verify the database was created
if [ ! -f "assets/db/hymns.isar" ]; then
    echo "❌ Error: Database file not created"
    exit 1
fi

echo
echo "✅ Build complete!"
echo "   Database: assets/db/hymns.isar"
echo "   Size: $(du -h assets/db/hymns.isar | cut -f1)"
echo

# Clean up
rm -rf "$TEMP_DIR"
```

### Step 2: Update HymnDbService

Modify `lib/services/hymn_db_service.dart` to copy the pre-built database from assets:

```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hymn_db.dart';

class HymnDbService {
  static Isar? _isar;

  static Future<Isar> get isar async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/hymns.isar';

    // Check if database exists
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      print('Copying pre-built database from assets...');

      // Copy from assets
      final data = await rootBundle.load('assets/db/hymns.isar');
      final bytes = data.buffer.asUint8List();
      await dbFile.writeAsBytes(bytes);

      print('Database copied successfully!');
    }

    _isar = await Isar.open(
      [HymnDbSchema],
      directory: dir.path,
      name: 'hymns',
    );

    return _isar!;
  }

  static Future<void> initializeDatabase() async {
    // Just open the database - it's already populated from assets
    await isar;
    final db = await isar;
    final count = await db.hymnDbs.count();
    print('Database ready with $count hymns');
  }

  // ... rest of the methods remain the same
}
```

### Step 3: Update pubspec.yaml

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/                    # Include available_hymns.json and db/
    # DO NOT include hymns/ directory anymore
```

### Step 4: Update Build Process

Add to your CI/CD or pre-build steps:

```bash
# Before building the app
./tool/build_db.sh

# Then build the app
flutter build ios --release
flutter build apk --release
```

## Alternative: Simpler Manual Approach

If the automated script is complex, you can build the database manually:

### Manual Build Steps:

1. **Generate index file:**
   ```bash
   dart run tool/build_database.dart
   ```

2. **Add temporary button to app** to trigger database build (like the DbBuilderScreen we created)

3. **Run the app once:**
   ```bash
   flutter run -d macos
   # Click the "Build Database" button in the app
   ```

4. **The database will be exported** to `assets/db/hymns.isar`

5. **Update pubspec.yaml** to exclude `hymns/` and include `assets/db/`

6. **Update HymnDbService** to copy from assets (see Step 2 above)

7. **Remove the build button** from production builds

## Benefits of Pre-Built Database

| Aspect | Before | After |
|--------|--------|-------|
| First launch time | 10-15 seconds | < 1 second |
| App bundle size | ~15-20 MB (JSON) | ~8-10 MB (database) |
| User experience | Poor (waiting) | Excellent (instant) |
| Deployment | Ship 2648 files | Ship 1 file |

## Version Management

When updating hymns:

1. Update JSON files in `hymns/` directory
2. Run `./tool/build_db.sh` to rebuild database
3. Commit the new `assets/db/hymns.isar` to git
4. Build and deploy the app

Consider adding a version check:
- Store database version in app (e.g., in shared preferences)
- If app version changes, re-copy database from assets
- This ensures users get updated hymns after app updates

## File Structure

```
hymnal_mobile/
├── assets/
│   ├── available_hymns.json          # Index file (for reference)
│   └── db/
│       ├── hymns.isar                # Pre-built database ✅
│       ├── hymns.isar.lock
│       └── hymns.isar.tmp
├── hymns/                            # NOT included in build ❌
│   ├── h_1.json
│   └── ...
├── tool/
│   ├── build_database.dart           # Generates index
│   └── build_db.sh                   # Full build script
└── lib/
    └── services/
        ├── hymn_db_service.dart      # Updated to copy from assets
        └── db_builder.dart            # Helper for manual building
```

## Testing

After implementing:

1. Delete the app from device/simulator
2. Build and install fresh
3. Launch app - should start instantly
4. Open search - should work immediately
5. Check console - should see "Database ready with 2648 hymns"

No more "Building database..." or waiting on first launch!

## Troubleshooting

**Database file too large:**
- Isar databases are highly compressed
- 2648 hymns should be ~8-10 MB
- If larger, check that you're only storing necessary fields

**Database not found:**
- Verify `assets/db/hymns.isar` exists in project
- Check `pubspec.yaml` includes `assets/db/`
- Verify `rootBundle.load()` path is correct

**Database corrupted:**
- Rebuild database using build script
- Ensure Isar version matches between build and runtime
- Check that all `hymns.isar*` files are copied together
