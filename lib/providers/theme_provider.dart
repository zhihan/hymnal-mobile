import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The available app color themes. Each theme drives the Material 3
/// color scheme via [AppTheme.seedColor], so the tags, buttons, chords,
/// and other accents all follow the selected theme.
///
/// All themes are light mode for now; a separate dark mode will come later.
/// The banner ("app bar") wears the theme's clothing color via [bannerColor]:
/// blue keeps its current light-blue banner, while the dark clothing colors
/// get genuinely dark banners (a generated M3 scheme would wash them out).
enum AppTheme {
  blue('Blue', Colors.blue),
  black('Black', Color(0xFF212121)),
  burgundy('Burgundy', Color(0xFF7A1F2B)),
  green('Green', Color(0xFF2E6B34)),
  brown('Brown', Color(0xFF7A5C1F));

  const AppTheme(this.displayName, this.seedColor);

  final String displayName;
  final Color seedColor;

  /// Banner background: blue keeps its current light-blue look, the dark
  /// clothing colors wear the color itself.
  Color get bannerColor => this == AppTheme.blue
      ? ColorScheme.fromSeed(seedColor: seedColor).inversePrimary
      : seedColor;

  /// Banner foreground (title/icons) contrasting with [bannerColor].
  Color get onBannerColor =>
      this == AppTheme.blue ? const Color(0xFF1A1C1E) : Colors.white;
}

/// Holds the user's selected [AppTheme], persists it to SharedPreferences,
/// and exposes the corresponding [ThemeData].
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_theme';

  AppTheme _theme = AppTheme.blue;

  AppTheme get theme => _theme;

  ThemeData get themeData {
    var scheme = ColorScheme.fromSeed(seedColor: _theme.seedColor);
    if (_theme == AppTheme.black) {
      // A generated scheme turns a near-black seed into grey accents;
      // pin primary to the clothing color so the black theme reads as black.
      scheme = scheme.copyWith(primary: _theme.seedColor);
    }
    return ThemeData(
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _theme.bannerColor,
        foregroundColor: _theme.onBannerColor,
      ),
      useMaterial3: true,
    );
  }

  /// Always-light variant of the theme, used for the hymn reading display.
  /// The background/surface tokens come from a fixed neutral seed so the
  /// paper stays the same regardless of the selected theme; only the accent
  /// tokens (primary/onPrimary, primaryContainer/onPrimaryContainer) come
  /// from the selected theme's seed, so tags, chords, and the language-nav
  /// band still follow the theme.
  ThemeData get lightThemeData {
    final neutral = ColorScheme.fromSeed(seedColor: AppTheme.blue.seedColor);
    final accent = ColorScheme.fromSeed(seedColor: _theme.seedColor);
    final primary =
        _theme == AppTheme.black ? _theme.seedColor : accent.primary;
    return ThemeData(
      colorScheme: neutral.copyWith(
        primary: primary,
        onPrimary: accent.onPrimary,
        primaryContainer: accent.primaryContainer,
        onPrimaryContainer: accent.onPrimaryContainer,
      ),
      useMaterial3: true,
    );
  }

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
