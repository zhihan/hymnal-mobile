import 'package:flutter/material.dart';
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

  test('dark clothing colors use dark brightness, blue stays light', () {
    expect(AppTheme.blue.brightness, equals(Brightness.light));
    for (final t in [AppTheme.black, AppTheme.burgundy, AppTheme.green, AppTheme.brown]) {
      expect(t.brightness, equals(Brightness.dark), reason: t.displayName);
    }

    final provider = ThemeProvider();
    expect(provider.themeData.colorScheme.brightness, equals(Brightness.light));
  });

  test('lightThemeData is always light, even for dark themes', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await provider.load();
    await provider.setTheme(AppTheme.black);
    expect(provider.themeData.colorScheme.brightness, equals(Brightness.dark));
    expect(
      provider.lightThemeData.colorScheme.brightness,
      equals(Brightness.light),
    );
    // Same seed color drives both variants
    expect(
      provider.lightThemeData.colorScheme.primary,
      equals(
        ColorScheme.fromSeed(seedColor: AppTheme.black.seedColor)
            .primary,
      ),
    );
  });
}
