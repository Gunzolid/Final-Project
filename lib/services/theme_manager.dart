import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized theme helper that keeps the runtime [ThemeMode] in sync with a
/// persisted value so the user’s choice survives restarts on every platform.
class ThemeManager {
  static const _prefsKey = 'theme_mode';
  static SharedPreferences? _prefs;
  static final ValueNotifier<ThemeMode> _themeNotifier = ValueNotifier(
    ThemeMode.system,
  );

  /// Exposes the notifier so widgets (e.g. MaterialApp, ProfilePage) can listen
  /// for theme changes.
  static ValueNotifier<ThemeMode> get themeNotifier => _themeNotifier;

  /// Loads the stored theme mode (if any) before the UI starts.
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final stored = _prefs!.getString(_prefsKey);
    if (stored == null) return;
    try {
      final restored = ThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
      );
      _themeNotifier.value = restored;
    } catch (_) {
      // Ignore corrupt values and keep the default ThemeMode.system.
    }
  }

  /// Persists the selected [mode] and updates the notifier immediately.
  static Future<void> updateTheme(ThemeMode mode) async {
    _themeNotifier.value = mode;
    await _prefs?.setString(_prefsKey, mode.name);
  }
}

/// Backwards compatible export so existing files keep importing
/// `theme_manager.dart` and referencing [themeNotifier].
final ValueNotifier<ThemeMode> themeNotifier = ThemeManager.themeNotifier;
