# Build Process and Deployment Strategy

## Overview

The hymnal app uses an optimized deployment strategy for full-text search functionality. Instead of bundling a pre-built database, we:

1. Include all hymn JSON files in the app bundle (`hymns/` directory)
2. Generate an `available_hymns.json` index at build time
3. Build the Isar database on first app launch from the JSON files
4. Cache the database for subsequent launches

This approach provides several advantages:
- **Simpler build process**: No need for complex database pre-building
- **Cross-platform compatibility**: Works on all platforms without platform-specific database files
- **Flexibility**: Easy to update hymns by just updating JSON files
- **Efficient after first launch**: Database is cached and reused

## Build Process

### Prerequisites
- Flutter SDK installed
- All dependencies installed (`flutter pub get`)

### Steps

#### 1. Generate available_hymns.json

Before building the app, run the build script to generate the index file:

```bash
dart run tool/build_database.dart
```

This script:
- Scans the `hymns/` directory for all JSON files
- Creates a map of available hymns by category
- Generates `assets/available_hymns.json` with the index

Example output:
```
Starting build process...
Scanning category: h
  Found 1360 hymns in h
Scanning category: ch
  Found 780 hymns in ch
Scanning category: ts
  Found 508 hymns in ts

✅ Available hymns file generated!
   Location: assets/available_hymns.json
   Total hymns: 2648
   Categories: h, ch, ts
```

#### 2. Build the Flutter app

After generating the index, build the app as normal:

```bash
# For iOS
flutter build ios

# For Android
flutter build apk
flutter build appbundle

# For other platforms
flutter build macos
flutter build linux
flutter build windows
```

## First Launch Behavior

When the app launches for the first time:

1. The `HymnDbService.initializeDatabase()` is called in `main.dart`
2. It checks if the Isar database exists and has data
3. If empty, it reads `assets/available_hymns.json` to get the list of hymns
4. It loads each hymn JSON file and extracts:
   - Title
   - Full text (stripped from all verses/lines/segments)
   - Category
   - Hymn number
   - Metadata
5. It creates indexed entries in the Isar database for efficient full-text search
6. The database is saved in the app's documents directory

This process takes approximately 10-15 seconds for ~2600 hymns.

## Subsequent Launches

On subsequent launches:
- The app checks if the database already exists and has data
- If yes, it skips the population step
- The app starts immediately with full search functionality available

## Database Location

The Isar database is stored in:
- **iOS**: `~/Library/Application Support/<app_id>/default.isar`
- **Android**: `/data/data/<package>/files/default.isar`
- **macOS**: `~/Library/Containers/<app_id>/Data/Library/Application Support/default.isar`

## File Structure

```
hymnal_mobile/
├── assets/
│   └── available_hymns.json          # Generated index file
├── hymns/
│   ├── h_1.json                      # Hymn JSON files
│   ├── h_2.json
│   ├── ch_1.json
│   └── ...
├── lib/
│   ├── models/
│   │   └── hymn_db.dart              # Isar database model
│   ├── services/
│   │   ├── hymn_db_service.dart      # Database service
│   │   └── db_builder.dart           # Optional: manual DB builder
│   └── screens/
│       └── search_screen.dart        # Search UI
└── tool/
    └── build_database.dart           # Build script
```

## Assets Included in App Bundle

The `pubspec.yaml` includes:
```yaml
assets:
  - hymns/                            # All hymn JSON files (~2648 files)
  - assets/                           # Index file (available_hymns.json)
```

## Estimated Sizes

- **Hymn JSON files**: ~15-20 MB (2648 files)
- **Isar database**: ~8-10 MB (after first launch)
- **Total app bundle increase**: ~15-20 MB (only JSON files shipped)

## Optimization Notes

### Current Approach (Implemented)
✅ Ship JSON files + build database on first launch
- Pros: Simple, cross-platform, flexible
- Cons: First launch is slower (~10-15 seconds)

### Alternative Approach (Not Implemented)
❌ Pre-build database and ship database file
- Pros: Instant search on first launch
- Cons: Complex build process, platform-specific database files, larger bundle size

The current approach was chosen because:
1. **Simplicity**: Easier to maintain and update
2. **Cross-platform**: Works identically on all platforms
3. **Acceptable trade-off**: 10-15 second first-launch delay is acceptable for the benefits gained

## Updating Hymns

To update hymns:

1. Update JSON files in the `hymns/` directory
2. Run `dart run tool/build_database.dart` to regenerate the index
3. Rebuild the app
4. On first launch after update, users will need to clear app data or the app should detect version changes and rebuild the database

## CI/CD Integration

For automated builds, add this step before `flutter build`:

```yaml
- name: Generate hymn index
  run: dart run tool/build_database.dart
```

## Troubleshooting

### Database not populating on first launch
- Check that `assets/available_hymns.json` exists
- Verify that `hymns/` directory is included in `pubspec.yaml`
- Check console for error messages during population

### Search not finding hymns
- Verify database was populated (check console for "Database populated with X hymns")
- Ensure full-text index is created (check `HymnDb` model has `@Index` annotations)
- Try clearing app data and relaunching

### Build errors
- Run `flutter clean` and `flutter pub get`
- Regenerate Isar schema: `flutter pub run build_runner build --delete-conflicting-outputs`
- Check that all dependencies are up to date
