// app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.light); // start in light mode

  static const Color mint = Color(0xFF02C39A);
  static const Color green = Color(0xFF76C893);
  static const Color teal = Color(0xFF34A0A4);

  // Dark gradient (unchanged)
  static const LinearGradient darkGradient = LinearGradient(
    colors: [
      Color(0xFF021817),
      Color(0xFF053033),
      Color(0xFF0C4B50),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Make top of light gradient bright instead of dark.
  static LinearGradient lightGradient(ColorScheme scheme) {
    return const LinearGradient(
      colors: [
        Color(0xFFF3FBF7), // very light at top
        Color(0xFFE6F7F1),
        Colors.white,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  static BoxDecoration backgroundDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: isDark ? darkGradient : lightGradient(scheme),
    );
  }
static BoxDecoration background(BuildContext context) => BoxDecoration(
  gradient: RadialGradient(
    colors: [Colors.white.withValues(alpha: 0.02), Colors.transparent],
  ),
);

  static BoxDecoration glassCardDecoration(
    BuildContext context, {
    double radius = 24,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: isDark
          ? Colors.white.withValues(alpha:0.07)
          : Colors.white.withValues(alpha:0.80),
      border: Border.all(color: Colors.white.withValues(alpha:0.25)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha:0.12),
          blurRadius: 20,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static ButtonStyle pillButton(BuildContext context, {bool primary = false}) {
    final scheme = Theme.of(context).colorScheme;
    return ElevatedButton.styleFrom(
      backgroundColor:
          primary ? scheme.primary : scheme.surface.withValues(alpha:0.35),
      foregroundColor: primary ? scheme.onPrimary : scheme.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      elevation: primary ? 6 : 0,
    );
  }

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor:
        const Color(0xFFF3FBF7), // solid light background for all pages[web:46][web:49]
    colorScheme: const ColorScheme.light(
      primary: mint,
      secondary: teal,
      background: Color(0xFFF3FBF7),
      surface: Colors.white,
      onPrimary: Colors.white,
      onSurface: Color(0xFF102422),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF021817),
    colorScheme: const ColorScheme.dark(
      primary: mint,
      secondary: green,
      background: Color(0xFF021817),
      surface: Color(0xFF072728),
      onPrimary: Color(0xFF021817),
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
  );
}
