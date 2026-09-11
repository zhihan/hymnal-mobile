import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The available app color themes. Each theme drives the Material 3
/// color scheme via [AppTheme.seedColor], so the banner, tags, buttons,
/// and other accents all follow the selected theme.
enum AppTheme {
  blue('Blue', Colors.blue),
  black('Black', Color(0xFF212121)),
  burgundy('Burgundy', Color(0xFF7A1F2B)),
  green('Green', Color(0xFF2E6B34)),
  brown('Brown', Color(0xFF5D4037));

  const AppTheme(this.displayName, this.seedColor);

  final String displayName;
  final Color seedColor;
}

/// Holds the user's selected [AppTheme], persists it to SharedPreferences,
/// and exposes the corresponding [ThemeData].
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_theme';

  AppTheme _theme = AppTheme.blue;

  AppTheme get theme => _theme;

  ThemeData get themeData => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _theme.seedColor),
        useMaterial3: true,
      );

  /// Loads the saved theme. Defaults to [AppTheme.blue] when nothing is saved.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefsKey);
    if (name != null) {
      for (final t in AppTheme.values) {
        if (t.name == name) {
          _theme = t;
          break;
        }
      }
    }
    notifyListeners();
  }

  /// Selects a new theme and persists it.
  Future<void> setTheme(AppTheme theme) async {
    if (_theme == theme) return;
    _theme = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, theme.name);
  }
}
