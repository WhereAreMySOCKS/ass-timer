import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFF6F0E6);
  static const sidebar = Color(0xFFF0E6D7);
  static const surface = Color(0xFFFFFCF5);
  static const muted = Color(0xFFF8EEDF);
  static const border = Color(0xFFE4D6C1);
  static const text = Color(0xFF211B17);
  static const secondaryText = Color(0xFF756B61);
  static const accent = Color(0xFF087F73);
  static const accentHover = Color(0xFF066B61);
  static const accentSoft = Color(0xFFDDF3EE);
  static const coral = Color(0xFFFF6A5F);
  static const success = Color(0xFF087F73);
  static const danger = Color(0xFFC34238);
  static const dangerSoft = Color(0xFFFCE7E4);
  static const warning = Color(0xFF8A5A12);
  static const warningSoft = Color(0xFFFFF1CF);
  static const comicPaper = surface;
  static const comicInk = text;
}

@immutable
class AppVisualTokens extends ThemeExtension<AppVisualTokens> {
  const AppVisualTokens({
    required this.canvas,
    required this.surface,
    required this.mutedSurface,
    required this.text,
    required this.secondaryText,
    required this.border,
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.coral,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.spaceUnit,
    required this.controlRadius,
    required this.cardRadius,
    required this.bubbleRadius,
    required this.hoverDuration,
    required this.transitionDuration,
    required this.emphasisDuration,
    required this.surfaceShadow,
    required this.floatingShadow,
  });

  static const standard = AppVisualTokens(
    canvas: AppColors.canvas,
    surface: AppColors.surface,
    mutedSurface: AppColors.muted,
    text: AppColors.text,
    secondaryText: AppColors.secondaryText,
    border: AppColors.border,
    primary: AppColors.accent,
    primaryHover: AppColors.accentHover,
    primarySoft: AppColors.accentSoft,
    coral: AppColors.coral,
    danger: AppColors.danger,
    dangerSoft: AppColors.dangerSoft,
    warning: AppColors.warning,
    warningSoft: AppColors.warningSoft,
    spaceUnit: 4,
    controlRadius: 10,
    cardRadius: 14,
    bubbleRadius: 18,
    hoverDuration: Duration(milliseconds: 120),
    transitionDuration: Duration(milliseconds: 180),
    emphasisDuration: Duration(milliseconds: 260),
    surfaceShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x10000000),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
    floatingShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x24000000),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );

  final Color canvas;
  final Color surface;
  final Color mutedSurface;
  final Color text;
  final Color secondaryText;
  final Color border;
  final Color primary;
  final Color primaryHover;
  final Color primarySoft;
  final Color coral;
  final Color danger;
  final Color dangerSoft;
  final Color warning;
  final Color warningSoft;
  final double spaceUnit;
  final double controlRadius;
  final double cardRadius;
  final double bubbleRadius;
  final Duration hoverDuration;
  final Duration transitionDuration;
  final Duration emphasisDuration;
  final List<BoxShadow> surfaceShadow;
  final List<BoxShadow> floatingShadow;

  @override
  AppVisualTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? mutedSurface,
    Color? text,
    Color? secondaryText,
    Color? border,
    Color? primary,
    Color? primaryHover,
    Color? primarySoft,
    Color? coral,
    Color? danger,
    Color? dangerSoft,
    Color? warning,
    Color? warningSoft,
    double? spaceUnit,
    double? controlRadius,
    double? cardRadius,
    double? bubbleRadius,
    Duration? hoverDuration,
    Duration? transitionDuration,
    Duration? emphasisDuration,
    List<BoxShadow>? surfaceShadow,
    List<BoxShadow>? floatingShadow,
  }) =>
      AppVisualTokens(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        mutedSurface: mutedSurface ?? this.mutedSurface,
        text: text ?? this.text,
        secondaryText: secondaryText ?? this.secondaryText,
        border: border ?? this.border,
        primary: primary ?? this.primary,
        primaryHover: primaryHover ?? this.primaryHover,
        primarySoft: primarySoft ?? this.primarySoft,
        coral: coral ?? this.coral,
        danger: danger ?? this.danger,
        dangerSoft: dangerSoft ?? this.dangerSoft,
        warning: warning ?? this.warning,
        warningSoft: warningSoft ?? this.warningSoft,
        spaceUnit: spaceUnit ?? this.spaceUnit,
        controlRadius: controlRadius ?? this.controlRadius,
        cardRadius: cardRadius ?? this.cardRadius,
        bubbleRadius: bubbleRadius ?? this.bubbleRadius,
        hoverDuration: hoverDuration ?? this.hoverDuration,
        transitionDuration: transitionDuration ?? this.transitionDuration,
        emphasisDuration: emphasisDuration ?? this.emphasisDuration,
        surfaceShadow: surfaceShadow ?? this.surfaceShadow,
        floatingShadow: floatingShadow ?? this.floatingShadow,
      );

  @override
  AppVisualTokens lerp(covariant AppVisualTokens? other, double t) {
    if (other == null) return this;
    return AppVisualTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t)!,
      text: Color.lerp(text, other.text, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      spaceUnit: lerpDouble(spaceUnit, other.spaceUnit, t)!,
      controlRadius: lerpDouble(controlRadius, other.controlRadius, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      bubbleRadius: lerpDouble(bubbleRadius, other.bubbleRadius, t)!,
      hoverDuration: t < 0.5 ? hoverDuration : other.hoverDuration,
      transitionDuration:
          t < 0.5 ? transitionDuration : other.transitionDuration,
      emphasisDuration: t < 0.5 ? emphasisDuration : other.emphasisDuration,
      surfaceShadow: t < 0.5 ? surfaceShadow : other.surfaceShadow,
      floatingShadow: t < 0.5 ? floatingShadow : other.floatingShadow,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppVisualTokens get visualTokens =>
      Theme.of(this).extension<AppVisualTokens>() ?? AppVisualTokens.standard;
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    primaryContainer: AppColors.accentSoft,
    onPrimaryContainer: AppColors.text,
    secondary: AppColors.coral,
    onSecondary: AppColors.text,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.border,
    outlineVariant: AppColors.muted,
  );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppVisualTokens.standard.controlRadius),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    canvasColor: AppColors.canvas,
    fontFamily: Platform.isMacOS ? null : 'NotoSansSC',
    fontFamilyFallback: const <String>['Segoe UI Emoji', 'Apple Color Emoji'],
    visualDensity: VisualDensity.standard,
    focusColor: AppColors.accentSoft,
    hoverColor: AppColors.accent.withValues(alpha: 0.06),
    splashColor: AppColors.accent.withValues(alpha: 0.10),
    extensions: const <ThemeExtension<dynamic>>[AppVisualTokens.standard],
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: AppColors.text,
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: AppColors.text,
        fontSize: 14,
        height: 1.45,
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
      labelLarge: TextStyle(
        color: AppColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.secondaryText),
      hintStyle: const TextStyle(color: AppColors.secondaryText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 40),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.secondaryText,
        shape: controlShape,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(76, 40),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: controlShape,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        shape: controlShape,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.secondaryText,
        hoverColor: AppColors.accentSoft,
        focusColor: AppColors.accentSoft,
        shape: controlShape,
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: const TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(color: AppColors.text, fontSize: 13),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: AppColors.surface, fontSize: 12),
      waitDuration: const Duration(milliseconds: 450),
    ),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.showShadow = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final bool showShadow;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(context.visualTokens.cardRadius),
          boxShadow: showShadow ? context.visualTokens.surfaceShadow : const [],
        ),
        child: Padding(padding: padding, child: child),
      );
}
