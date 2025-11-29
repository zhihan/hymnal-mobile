# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter mobile application for displaying hymnals with chords inlined. The app is primarily targeted at Android devices, with potential future expansion to iOS.

**Data Source**: Hymnal data (songs, lyrics, chords) is fetched from Google Cloud Firestore.

## Setup and Installation

**Prerequisites**:
- Flutter SDK installed (https://docs.flutter.dev/get-started/install)
- Android SDK and Android Studio for Android development
- Firebase project configured with Firestore database

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

**Firebase Configuration**:
- Add `google-services.json` to `android/app/` directory for Android
- Add `GoogleService-Info.plist` to `ios/Runner/` directory for iOS (if implemented)
- Configure Firebase in `lib/main.dart` with `Firebase.initializeApp()`

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
- Use Provider, Riverpod, or Bloc pattern for state management (to be determined during development)
- Keep Firestore queries and data fetching logic separate from UI components

**Directory Structure**:
```
lib/
├── main.dart              # App entry point, Firebase initialization
├── models/                # Data models (Hymn, Chord, etc.)
├── services/              # Business logic layer
│   └── firestore_service.dart  # Firestore data access
├── screens/               # Full-screen pages
│   ├── home_screen.dart
│   └── hymn_detail_screen.dart
├── widgets/               # Reusable UI components
│   └── chord_display_widget.dart
└── utils/                 # Helper functions and constants
```

**Data Flow**:
1. Firestore service layer fetches hymnal data from Firebase
2. Models represent the data structure (Hymn, lyrics with chord positions)
3. State management updates UI when data changes
4. Widgets display hymnals with chords positioned inline with lyrics

## Firestore Data Structure

Expected Firestore collections and document structure:

**Collection: `hymnals`**
```
{
  "id": "hymn_001",
  "title": "Amazing Grace",
  "number": 1,
  "lyrics": [
    {
      "line": "Amazing grace how sweet the sound",
      "chords": [
        {"position": 0, "chord": "G"},
        {"position": 16, "chord": "C"}
      ]
    }
  ],
  "metadata": {
    "author": "...",
    "year": "...",
    "key": "G"
  }
}
```

## Key Development Considerations

**Firestore Integration**:
- Use `cloud_firestore` package for Firestore access
- Implement proper error handling for network failures
- Consider caching strategies for offline access
- Use StreamBuilder or FutureBuilder for reactive UI updates

**Chord Display**:
- Chords should be displayed inline above or within lyrics
- Position chords accurately relative to syllables/words
- Consider using monospace fonts or careful spacing for alignment
- Handle different screen sizes and orientations

**Performance**:
- Paginate or limit Firestore queries to avoid loading all hymnals at once
- Cache frequently accessed hymnals locally
- Optimize widget rebuilds with const constructors where possible

**Android-First Development**:
- Test primarily on Android devices/emulators
- Follow Material Design guidelines
- Configure Android-specific permissions in `android/app/src/main/AndroidManifest.xml`

## Dependencies

Key packages to include in `pubspec.yaml`:
- `firebase_core`: Firebase initialization
- `cloud_firestore`: Firestore database access
- State management package (provider/riverpod/bloc)
- Additional UI packages as needed

## Common Issues

**Firebase not initialized**: Ensure `Firebase.initializeApp()` is called before any Firestore operations, typically in `main()` before `runApp()`.

**Firestore permissions**: Check Firestore security rules allow read access for the app.

**Build errors after adding Firebase**: Run `flutter clean && flutter pub get` and ensure `google-services.json` is in the correct location.
