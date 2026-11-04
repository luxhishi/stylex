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

  Color nightSurface(Color color) {
    if (!isDark || color.a == 0) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.22) return color;
    return hsl
        .withSaturation((hsl.saturation * 0.55).clamp(0.0, 0.45))
        .withLightness(hsl.lightness > 0.7 ? 0.13 : 0.22)
        .toColor();
  }

  Color nightInk(Color color) {
    if (!isDark || color.a == 0) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < 0.25) {
      return const Color(0xFFCCD8D5).withValues(alpha: color.a);
    }
    return hsl
        .withSaturation(hsl.saturation.clamp(0.0, 0.5))
        .withLightness(0.64)
        .toColor();
  }

  Color nightOutline(Color color) =>
      isDark ? const Color(0xFF354845).withValues(alpha: color.a) : color;

  List<Color> nightSurfaces(List<Color> colors) =>
      colors.map(nightSurface).toList();
}

/// Keep photo colors unchanged in both themes.
class NightImage extends StatelessWidget {
  const NightImage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
