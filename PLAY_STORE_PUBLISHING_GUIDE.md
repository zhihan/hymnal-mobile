# Google Play Store Publishing Guide

This guide walks you through publishing the 诗歌 with Chords app to the Google Play Store.

## Prerequisites

Before you begin, ensure you have:
- Flutter SDK installed and configured
- Android SDK installed
- A Google Play Console developer account ($25 one-time fee)
- Your app keystore created (see steps below)

## Step 1: Create Your App Keystore

**IMPORTANT**: The keystore is used to sign your app. If you lose it, you cannot update your app on the Play Store!

1. Generate the keystore:
```bash
cd android
keytool -genkey -v -keystore ~/hymns-mobile-upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

2. You'll be prompted for:
   - Keystore password (choose a strong password)
   - Key password (can be same as keystore password)
   - Your name and organization details

3. Create the `key.properties` file:
```bash
cd android
cp key.properties.template key.properties
```

4. Edit `android/key.properties` with your actual values:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/YOUR_USERNAME/hymns-mobile-upload-keystore.jks
```

**Store your keystore and passwords securely!** Consider:
- Backing up the keystore file to a secure location
- Using a password manager for the passwords
- Keeping offline backups

## Step 2: Review and Update App Version

Edit `pubspec.yaml` to update the version number:

```yaml
version: 1.1.0+2  # Format: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

- The first part (1.1.0) is the version name shown to users
- The number after + is the version code (must increase with each release)

## Step 3: Build the Release Bundle

Google Play Store requires an **Android App Bundle (AAB)** format:

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build the release bundle
flutter build appbundle --release
```

The AAB file will be created at:
```
build/app/outputs/bundle/release/app-release.aab
```

### Optional: Build APK for Testing

If you want to test the release APK first:

```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Step 4: Test the Release Build

Before uploading, test your release build:

1. Install the APK on a device:
```bash
flutter install --release
```

2. Test all features:
   - [ ] App launches successfully
   - [ ] Search functionality works
   - [ ] Deep linking works (test with: `https://cicmusic.net/hymn/ts/1`)
   - [ ] Sharing hymns works
   - [ ] Favorites/song lists work
   - [ ] Navigation between hymns works
   - [ ] Transpose functionality works

## Step 5: Prepare Play Store Assets

You'll need to prepare the following for the Play Store listing:

### Required Assets:

1. **App Icon**: Already configured at `assets/icon/app_icon.png`

2. **Screenshots** (at least 2, up to 8):
   - Phone: 16:9 or 9:16 ratio
   - Recommended: 1080x1920 or 1920x1080
   - Show key features: home screen, hymn display, search, etc.

3. **Feature Graphic**:
   - Size: 1024 x 500 pixels
   - Used in Play Store promotions

4. **App Description**:
   - Short description (up to 80 characters)
   - Full description (up to 4000 characters)

### Example Short Description:
```
Browse and view Chinese and English hymns with chord support and search
```

### Example Full Description:
```
诗歌 with Chords provides easy access to thousands of Chinese and English hymns with
integrated chord display and transposition features.

FEATURES:
• Browse hymns from multiple hymnals (补充本, 大本, Hymns, New Songs)
• Full-text search across all hymns
• Chord display with transpose functionality
• Create and manage custom song lists
• Share hymns via deep links
• Clean, easy-to-read interface
• Offline support - all hymns stored locally

HYMNALS INCLUDED:
• 补充本 (Supplement)
• 大本 (Classic Chinese Hymns)
• Hymns (English)
• New Songs

Perfect for musicians, worship leaders, and anyone who wants quick access to
hymns with chords.
```

5. **Privacy Policy**:
   - Required if your app collects user data
   - Must be hosted online (URL required)

6. **Content Rating**:
   - You'll complete a questionnaire in Play Console
   - Expected rating: Everyone

## Step 6: Upload to Play Console

1. Go to [Google Play Console](https://play.google.com/console)

2. Create a new app:
   - Click "Create app"
   - Fill in app details:
     - App name: "诗歌 with Chords"
     - Default language: English (United States)
     - App/Game: App
     - Free/Paid: Free

3. Complete the app setup checklist:
   - Set up your app (Store listing, Content rating, etc.)
   - Upload the AAB file to the Production track
   - Complete the Content rating questionnaire
   - Set up pricing & distribution
   - Add privacy policy (if applicable)

4. Upload your app bundle:
   - Go to Release > Production
   - Click "Create new release"
   - Upload `app-release.aab`
   - Add release notes
   - Review and roll out

## Step 7: Domain Verification (Deep Linking)

To enable deep linking with cicmusic.net:

1. In Google Play Console, go to: App > Setup > App Integrity > App Signing

2. Download the SHA-256 certificate fingerprint

3. Add a `.well-known/assetlinks.json` file to your web server at:
   ```
   https://cicmusic.net/.well-known/assetlinks.json
   ```

4. Content should be:
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "net.cicmusic.hymns_mobile",
    "sha256_cert_fingerprints":
    ["YOUR_SHA256_FINGERPRINT_FROM_PLAY_CONSOLE"]
  }
}]
```

5. Verify at: https://developers.google.com/digital-asset-links/tools/generator

## Step 8: Submit for Review

1. Review all information in Play Console
2. Click "Send for review"
3. Wait for Google's review (typically 1-3 days)

## Step 9: Post-Publication

After your app is published:

1. Monitor the Play Console for:
   - Crash reports
   - User reviews
   - Download statistics

2. Respond to user reviews

3. Plan updates as needed

## Updating Your App

When you need to release an update:

1. Increment the version in `pubspec.yaml`:
   ```yaml
   version: 1.1.1+3  # Increment version name and code
   ```

2. Rebuild:
   ```bash
   flutter build appbundle --release
   ```

3. Upload to Play Console:
   - Create a new release in Production
   - Upload the new AAB
   - Add release notes describing changes
   - Submit for review

## Troubleshooting

### Build Failures

If the build fails:
```bash
flutter clean
flutter pub get
flutter build appbundle --release --verbose
```

### Keystore Issues

If you get keystore errors:
- Verify `android/key.properties` exists and has correct values
- Check that the keystore file path is absolute and correct
- Ensure passwords match what you used when creating the keystore

### ProGuard Issues

If the app crashes in release but works in debug:
- Check `android/app/proguard-rules.pro`
- Add keep rules for classes that are failing
- Test with: `flutter run --release`

### Deep Link Verification

Test deep linking:
```bash
# Open a hymn via deep link
adb shell am start -a android.intent.action.VIEW \
  -d "https://cicmusic.net/hymn/ts/1" net.cicmusic.hymns_mobile
```

## Resources

- [Flutter Publishing Guide](https://docs.flutter.dev/deployment/android)
- [Google Play Console](https://play.google.com/console)
- [Play Store Policies](https://play.google.com/about/developer-content-policy/)
- [Android App Links](https://developer.android.com/training/app-links)

## Checklist

Before submitting to Play Store:

- [ ] Keystore created and backed up securely
- [ ] `key.properties` configured correctly
- [ ] Version number updated in `pubspec.yaml`
- [ ] Release build tested on real device
- [ ] All features working (search, favorites, deep links, sharing)
- [ ] Screenshots prepared (at least 2)
- [ ] Feature graphic created (1024x500)
- [ ] App description written
- [ ] Privacy policy prepared (if needed)
- [ ] Content rating completed
- [ ] Deep linking verified with assetlinks.json
- [ ] Release notes written

Good luck with your Play Store launch! 🚀
