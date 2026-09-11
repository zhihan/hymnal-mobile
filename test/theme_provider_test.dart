import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymns_mobile/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to blue theme when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await provider.load();
    expect(provider.theme, equals(AppTheme.blue));
  });

  test('persists the selected theme', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await provider.load();

    await provider.setTheme(AppTheme.burgundy);
    expect(provider.theme, equals(AppTheme.burgundy));

    // A fresh provider should load the saved theme
    final reloaded = ThemeProvider();
    await reloaded.load();
    expect(reloaded.theme, equals(AppTheme.burgundy));
  });

  test('setTheme notifies listeners', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await provider.load();

    var notified = 0;
    provider.addListener(() => notified++);

    await provider.setTheme(AppTheme.green);
    expect(notified, equals(1));

    // Setting the same theme again is a no-op
    await provider.setTheme(AppTheme.green);
    expect(notified, equals(1));
  });

  test('every theme has a display name and a distinct seed color', () {
    final names = AppTheme.values.map((t) => t.displayName).toSet();
    expect(names.length, equals(AppTheme.values.length));

    final seeds = AppTheme.values.map((t) => t.seedColor).toSet();
    expect(seeds.length, equals(AppTheme.values.length));
  });

  test('all themes are light mode for now', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await provider.load();
    for (final t in AppTheme.values) {
      await provider.setTheme(t);
      expect(
        provider.themeData.colorScheme.brightness,
        equals(Brightness.light),
        reason: t.displayName,
      );
      expect(
        provider.lightThemeData.colorScheme.brightness,
        equals(Brightness.light),
        reason: t.displayName,
      );
    }
  });

  test('lightThemeData background/surface stay fixed across themes', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await provider.load();

    final reference = ColorScheme.fromSeed(seedColor: AppTheme.blue.seedColor);

    for (final t in AppTheme.values) {
      await provider.setTheme(t);
      final scheme = provider.lightThemeData.colorScheme;
      expect(scheme.surface, equals(reference.surface), reason: t.displayName);
      expect(
        scheme.surfaceContainerHighest,
        equals(reference.surfaceContainerHighest),
        reason: t.displayName,
      );
      expect(scheme.outline, equals(reference.outline), reason: t.displayName);
    }
  });

  test('lightThemeData accents still follow the selected theme', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await provider.load();

    final primaries = <Color>{};
    for (final t in AppTheme.values) {
      await provider.setTheme(t);
      primaries.add(provider.lightThemeData.colorScheme.primary);
    }
    // Every theme should produce a distinct accent color for tags/chords.
    expect(primaries.length, equals(AppTheme.values.length));
  });

  test('banner wears the clothing color; blue keeps its light banner', () {
    // Blue keeps the exact current light-blue banner with dark text.
    expect(
      AppTheme.blue.bannerColor,
      equals(
        ColorScheme.fromSeed(seedColor: Colors.blue).inversePrimary,
      ),
    );
    expect(AppTheme.blue.onBannerColor, equals(const Color(0xFF1A1C1E)));

    // Dark clothing colors get genuinely dark banners with white text.
    for (final t in [
      AppTheme.black,
      AppTheme.burgundy,
      AppTheme.green,
      AppTheme.brown,
    ]) {
      expect(t.bannerColor, equals(t.seedColor), reason: t.displayName);
      expect(t.onBannerColor, equals(Colors.white), reason: t.displayName);
    }
  });

  test('black theme primary is pinned to the clothing color', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await provider.load();
    await provider.setTheme(AppTheme.black);
    // A generated scheme would wash the near-black seed out to grey.
    expect(
      provider.themeData.colorScheme.primary,
      equals(AppTheme.black.seedColor),
    );
  });
}
