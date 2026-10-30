import 'package:flutter/material.dart';

/// ألوان هوية SOFYAN YT (مأخوذة من الواجهة الأصلية: خلفية #0b1230 → #1a1450، بنفسجي/نيلي).
class Brand {
  static const Color bg1 = Color(0xFF0B1230);
  static const Color bg2 = Color(0xFF1A1450);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetLight = Color(0xFFA78BFA);
  static const Color indigo = Color(0xFF6366F1);
  static const Color amber = Color(0xFFFCD34D);
  static const Color red = Color(0xFFFCA5A5);
  static const Color green = Color(0xFF34D399);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.violet,
    brightness: b,
  ).copyWith(
    primary: dark ? Brand.violetLight : Brand.violet,
    surface: dark ? Brand.bg1 : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: dark ? Brand.bg1 : Colors.white,
    dividerColor: dark ? const Color(0x1AFFFFFF) : const Color(0x1A000000),
  );
}

extension ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get textMain => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textMuted => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get cardColor => isDark ? const Color(0x0DFFFFFF) : Colors.white;
  Color get cardBorder => isDark ? const Color(0x14FFFFFF) : const Color(0x1F6D28D9);
  Color get fieldColor => isDark ? const Color(0x4D000000) : const Color(0xFFF1F0FF);
  Color get chipColor => isDark ? const Color(0x1AFFFFFF) : const Color(0x1A8B5CF6);
}
