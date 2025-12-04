# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter mobile application for displaying hymnals with chords inlined. The app is primarily targeted at Android devices, with potential future expansion to iOS.

**Data Source**: Hymnal data (songs, lyrics, chords) is loaded from local JSON assets bundled with the app. The app uses an Isar database for search functionality and metadata indexing.

## Setup and Installation

**Prerequisites**:
- Flutter SDK installed (https://docs.flutter.dev/get-started/install)
- Android SDK and Android Studio for Android development
- iOS development tools (Xcode) for iOS devices

**Initial Setup**:
```bash
# Get dependencies
flutter pub get

# Run on Android device/emulator
flutter run

# Run on specific device
flutter run -d <device_id>

# List available devices
flutter devices
```

**Database Regeneration**:
If you need to rebuild the Isar database (after schema changes):
```bash
# Regenerate Isar schema files
dart run build_runner build --delete-conflicting-outputs

# The database will automatically repopulate on next app launch
# when the version number is incremented in hymn_db_service.dart
```

## Development Commands

**Running the app**:
```bash
flutter run                    # Run in debug mode
flutter run --release          # Run in release mode
flutter run -d android         # Run specifically on Android
```

**Testing**:
```bash
flutter test                   # Run all unit and widget tests
flutter test test/specific_test.dart  # Run a single test file
flutter test --coverage        # Run tests with coverage report
```

**Code Quality**:
```bash
flutter analyze                # Run static analysis
flutter format lib/            # Format code
flutter format --set-exit-if-changed lib/  # Check formatting
```

**Building**:
```bash
# Android
flutter build apk              # Build APK (debug)
flutter build apk --release    # Build release APK
flutter build appbundle        # Build Android App Bundle (for Play Store)

# iOS (if implemented)
flutter build ios              # Build iOS app
flutter build ipa              # Build IPA for App Store
```

**Clean and Reset**:
```bash
flutter clean                  # Clean build artifacts
flutter pub get                # Reinstall dependencies
```

## Project Architecture

**State Management**:
- Uses Provider package for state management (favorites feature)
- Keep data fetching logic separate from UI components in service layer

**Directory Structure**:
```
lib/
├── main.dart                   # App entry point with Provider setup
├── models/                     # Data models
│   ├── hymn_song.dart          # Main hymn display model
│   ├── hymn_db.dart            # Isar database collection model
│   ├── verse.dart, line.dart   # Hymn structure hierarchy
│   └── segment.dart, chord.dart # Chord data
├── services/                   # Business logic layer
│   ├── hymn_loader_service.dart # Asset loading & caching
│   ├── hymn_db_service.dart    # Isar database access
│   └── favorites_service.dart  # Favorites management
├── providers/                  # State management
│   └── favorites_provider.dart # Favorites state provider
├── screens/                    # Full-screen pages
│   ├── home_screen.dart        # Main entry, book & hymn number input
│   ├── hymn_detail_screen.dart # Hymn display with transpose/chords
│   ├── search_screen.dart      # Full-text search
│   └── favorites_screen.dart   # Favorited hymns list
├── widgets/                    # Reusable UI components
│   └── hymn_display.dart       # Hymn rendering with chords
└── utils/                      # Helper functions
    └── chord_transposer.dart   # Chord transposition logic
```

**Data Flow**:
1. JSON assets (hymns/) → HymnLoaderService (caches results) → HymnSong objects
2. For search: HymnLoaderService → HymnDbService (Isar DB with full-text indexing)
3. State management (Provider) updates UI when favorites change
4. Widgets display hymnals with chords positioned inline with lyrics

## Data Structure

### Hymn JSON Files (assets/hymns/)

Hymn files are named with the format: `{bookId}_{number}.json` (e.g., `ts_1.json`, `ch_100.json`, `h_500.json`, `ns_50.json`)

**Key Terminology**:
- **bookId**: The identifier for the hymn book (e.g., "ts", "ch", "h", "ns"). This is part of the hymn ID.
- **category**: The descriptive category from metadata (e.g., "Ultimate Manifestation", "God's Economy"). This is NOT the same as bookId.
- **hymnId**: The full identifier combining bookId and number (e.g., "ts_1", "ch_100")

**Book IDs**:
- `ts`: 補充本 (Supplement)
- `ch`: 大本 (Classic Chinese Hymns)
- `h`: Hymns (English)
- `ns`: New Songs

**JSON Structure**:
```json
{
  "title": "Hymn Title",
  "url": "https://www.hymnal.net/...",
  "verses": [
    {
      "type": "verse",
      "lines": [
        {
          "segments": [
            {"text": "Amazing grace", "chord": {"name": "G"}},
            {"text": " how sweet the sound", "chord": {"name": "C"}}
          ]
        }
      ]
    }
  ],
  "metadata": {
    "category": "Ultimate Manifestation",
    "time": "3/4",
    "hymn_code": "51123321271",
    "related": [
      {
        "url": "https://www.hymnal.net/en/hymn/ch/100",
        "language": "zh",
        "category": "ch",
        "number": "100",
        "title": "Ch100"
      }
    ]
  }
}
```

### Database Models

**HymnDb** (Isar database model for search):
- `hymnId`: Full hymn identifier (e.g., "ts_1")
- `bookId`: Book identifier extracted from hymnId (e.g., "ts")
- `title`: Hymn title
- `number`: Hymn number within the book
- `category`: Descriptive category from metadata (e.g., "Ultimate Manifestation")
- `fullText`: Concatenated text for full-text search
- Indexed fields: hymnId, bookId, title, fullText (case-insensitive)

**HymnSong** (Display model):
- `title`: Hymn title
- `url`: Source URL
- `verses`: List of Verse objects containing Lines and Segments
- `metadata`: Map containing category, time, hymn_code, related hymns, etc.

### Important Notes

- **Always use `bookId`** when navigating or loading hymns (not `category`)
- **category** is a descriptive field from metadata and may contain values like "Ultimate Manifestation", "God's Economy", etc.
- **bookId** identifies which hymnal book the song comes from ("ts", "ch", "h", "ns")
- The hymn files use `"category"` in the related hymns section to mean `bookId` - this is a JSON structure naming convention

## Key Development Considerations

**Data Loading**:
- Hymns are loaded from local JSON assets (no network required)
- HymnLoaderService handles asset loading and caching
- Isar database provides fast full-text search functionality
- Database auto-rebuilds when version number is incremented

**Chord Display**:
- Chords should be displayed inline above or within lyrics
- Position chords accurately relative to syllables/words
- Consider using monospace fonts or careful spacing for alignment
- Handle different screen sizes and orientations

**Performance**:
- HymnLoaderService caches loaded hymns in memory
- Search queries are limited to 100 results for performance
- Optimize widget rebuilds with const constructors where possible
- InteractiveViewer allows pinch-zoom and pan for hymn display

**Platform Support**:
- Primary: iOS (tested on iPhone devices)
- Secondary: Android
- Follow Material Design guidelines
- Configure platform-specific permissions in respective manifest files

## Dependencies

Key packages in `pubspec.yaml`:
- `provider: ^6.1.2`: State management for favorites
- `isar: ^3.1.0+1`: Local database for search functionality
- `isar_flutter_libs: ^3.1.0+1`: Isar platform bindings
- `shared_preferences: ^2.3.3`: Simple key-value storage for favorites
- `path_provider: ^2.1.4`: File system access for database
- `build_runner: ^2.4.13`: Code generation
- `isar_generator: ^3.1.0+1`: Isar schema generation

## Common Issues

**Database not rebuilding**: Ensure you increment `_currentDbVersion` in `hymn_db_service.dart` after schema changes, then run the app. The database will automatically repopulate.

**Build runner errors**: Run `dart run build_runner build --delete-conflicting-outputs` after modifying any Isar collection models (files with `@collection` annotation).

**Navigation errors**: Always use `bookId` (not `category`) when navigating to hymns. The `category` field is descriptive metadata, while `bookId` identifies the hymnal book ("ts", "ch", "h", "ns").

**Favorites not persisting**: Favorites are stored in SharedPreferences with key `'favorite_hymns'` as a list of hymnIds. Check that SharedPreferences is working correctly on the target platform.
