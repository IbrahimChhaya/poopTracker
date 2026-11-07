import 'package:flutter/material.dart';

import 'morrow_colors.dart';
import 'morrow_tokens.dart';
import 'morrow_typography.dart';

/// The morrow light theme. v1 is light only; dark mode follows after v1 by
/// adding a second [MorrowColors] and building the same theme from it.
ThemeData buildMorrowTheme([MorrowColors c = MorrowColors.light]) {
  final text = buildMorrowTextTheme(c);
  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.tint,
    onPrimaryContainer: c.primary,
    secondary: c.primary,
    onSecondary: c.onPrimary,
    secondaryContainer: c.tint,
    onSecondaryContainer: c.primary,
    tertiary: c.warmIcon,
    onTertiary: c.card,
    tertiaryContainer: c.sand,
    onTertiaryContainer: c.ink,
    error: c.danger,
    onError: c.card,
    errorContainer: c.sand,
    onErrorContainer: c.danger,
    surface: c.background,
    onSurface: c.ink,
    surfaceContainerLowest: c.card,
    surfaceContainerLow: c.card,
    surfaceContainer: c.card,
    surfaceContainerHigh: c.card,
    surfaceContainerHighest: c.line,
    onSurfaceVariant: c.mutedText,
    outline: c.line,
    outlineVariant: c.line,
    shadow: c.ink,
    scrim: c.ink,
    inverseSurface: c.ink,
    onInverseSurface: c.card,
    inversePrimary: c.tint,
    surfaceTint: Colors.transparent,
  );

  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(MorrowRadii.md)),
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  const buttonMinSize = Size(64, MorrowSizes.buttonMinHeight);
  final barrier = c.ink.withValues(alpha: 0.5);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: morrowFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    dividerColor: c.line,
    splashFactory: InkSparkle.splashFactory,
    extensions: <ThemeExtension<dynamic>>[c, MorrowTextStyles.from(c)],
    iconTheme: IconThemeData(color: c.mutedIcon, size: 20),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(buttonMinSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: const WidgetStatePropertyAll(buttonShape),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.disabled) ? c.disabledSurface : c.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.disabled) ? c.disabledText : c.onPrimary,
        ),
        overlayColor: WidgetStatePropertyAll(
          c.onPrimary.withValues(alpha: 0.12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(buttonMinSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: const WidgetStatePropertyAll(buttonShape),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.mutedText : c.primary,
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.disabled) ? c.line : c.primary,
          ),
        ),
        overlayColor: WidgetStatePropertyAll(c.primary.withValues(alpha: 0.08)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(c.primary),
        textStyle: WidgetStatePropertyAll(
          text.titleSmall!.copyWith(fontSize: 14),
        ),
        shape: const WidgetStatePropertyAll(buttonShape),
      ),
    ),
    chipTheme: ChipThemeData(
      color: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.tint : c.card,
      ),
      side: WidgetStateBorderSide.resolveWith(
        (s) => BorderSide(
          color: s.contains(WidgetState.selected) ? c.primary : c.line,
        ),
      ),
      shape: const StadiumBorder(),
      showCheckmark: true,
      checkmarkColor: c.primary,
      labelStyle: text.bodySmall!.copyWith(color: c.ink),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      elevation: 0,
      pressElevation: 0,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(c.card),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.switchTrackOff,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.mutedIcon,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      circularTrackColor: c.tint,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      barrierColor: barrier,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(MorrowRadii.xxl)),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium!.copyWith(color: c.mutedText),
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      modalBackgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: barrier,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: c.line,
      dragHandleSize: const Size(40, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MorrowRadii.sheet),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: text.bodyMedium!.copyWith(
        color: c.card,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(MorrowRadii.md)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: c.tint,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? text.labelSmall!.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w600,
              )
            : text.labelSmall,
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected) ? c.primary : c.mutedIcon,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: c.card,
      hintStyle: text.bodyLarge!.copyWith(color: c.mutedText),
      contentPadding: const EdgeInsets.all(MorrowSpacing.lg),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(MorrowRadii.lg)),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(MorrowRadii.lg)),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(MorrowRadii.lg)),
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
    ),
  );
}
