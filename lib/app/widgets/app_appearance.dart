import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAppearance {
  static const _key = 'stylex_dark_mode';
  static final mode = ValueNotifier(ThemeMode.system);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_key);
    if (dark != null) mode.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDark(bool dark) async {
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, dark);
  }
}

extension StylexColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color adaptive(Color light, Color dark) => isDark ? dark : light;
}
