#!/bin/bash

# Build script for Play Store release
# This script automates the build process for releasing to Google Play Store

set -e  # Exit on error

echo "========================================="
echo "  诗歌 with Chords - Release Build Script"
echo "========================================="
echo ""

# Check if key.properties exists
if [ ! -f "android/key.properties" ]; then
    echo "❌ Error: android/key.properties not found!"
    echo "Please create your keystore and key.properties file first."
    echo "See android/CREATE_KEYSTORE.md for instructions."
    exit 1
fi

echo "✅ Found key.properties"
echo ""

# Get current version from pubspec.yaml
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
echo "Current version: $CURRENT_VERSION"
echo ""

# Ask if user wants to update version
read -p "Do you want to update the version? (y/n): " UPDATE_VERSION
if [ "$UPDATE_VERSION" = "y" ]; then
    read -p "Enter new version (e.g., 1.2.0+3): " NEW_VERSION
    sed -i.bak "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
    rm pubspec.yaml.bak
    echo "✅ Updated version to $NEW_VERSION"
    echo ""
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
echo "✅ Clean complete"
echo ""

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get
echo "✅ Dependencies updated"
echo ""

# Build App Bundle (for Play Store)
echo "🔨 Building Android App Bundle (AAB)..."
flutter build appbundle --release
echo "✅ App Bundle built successfully!"
echo ""

# Build APK (for testing)
echo "🔨 Building APK for testing..."
flutter build apk --release
echo "✅ APK built successfully!"
echo ""

# Display build locations
echo "========================================="
echo "  Build Complete! 🎉"
echo "========================================="
echo ""
echo "📦 App Bundle (for Play Store upload):"
echo "   build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "📱 APK (for testing):"
echo "   build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "Next steps:"
echo "1. Test the APK on a device: flutter install --release"
echo "2. Upload the AAB to Google Play Console"
echo "3. See PLAY_STORE_PUBLISHING_GUIDE.md for details"
echo ""
