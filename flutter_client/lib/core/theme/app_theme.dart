import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFF5F5F7);
  static const sidebar = Color(0xFFF0F0F2);
  static const surface = Color(0xFFFAFAFA);
  static const muted = Color(0xFFF2F2F4);
  static const border = Color(0xFFD5D5D9);
  static const text = Color(0xFF1D1D1F);
  static const secondaryText = Color(0xFF6E6E73);
  static const accent = Color(0xFF0A69D8);
  static const accentSoft = Color(0xFFDCEBFA);
  static const success = Color(0xFF0C8451);
  static const danger = Color(0xFFBD1C25);
  static const comicPaper = Color(0xFFFFFBEF);
  static const comicInk = Color(0xFF211B17);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.light,
    primary: AppColors.accent,
    error: AppColors.danger,
    surface: AppColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'NotoSansSC',
    fontFamilyFallback: const <String>[
      'Segoe UI Emoji',
      'Apple Color Emoji',
    ],
    visualDensity: VisualDensity.standard,
    focusColor: AppColors.accentSoft,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: AppColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: AppColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        color: AppColors.text,
        fontSize: 14,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        color: AppColors.secondaryText,
        fontSize: 12,
        height: 1.4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(104, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 42),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}

class AppCard extends StatelessWidget {
  const AppCard(
      {required this.child,
      super.key,
      this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
                color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Padding(padding: padding, child: child),
      );
}
