import 'package:flutter/material.dart';

import 'morrow_colors.dart';

/// Inter is bundled under assets/fonts (SIL Open Font Licence 1.1).
const String morrowFontFamily = 'Inter';

const FontWeight _regular = FontWeight.w400;
const FontWeight _medium = FontWeight.w500;
const FontWeight _semiBold = FontWeight.w600;

/// Type scale mapped from the Figma file onto Material text roles.
///
/// | Role           | Figma use                                   |
/// |----------------|---------------------------------------------|
/// | headlineLarge  | 30 SemiBold, page titles                    |
/// | headlineSmall  | 20 SemiBold, onboarding and empty headings  |
/// | titleLarge     | 18 SemiBold, dialog and sheet titles        |
/// | titleMedium    | 16 SemiBold, section headings               |
/// | titleSmall     | 15 SemiBold, list row titles                |
/// | bodyLarge      | 15 Regular, inputs and option labels        |
/// | bodyMedium     | 14 Regular (21 line height), body copy      |
/// | bodySmall      | 12 Regular (17 line height), row subtitles  |
/// | labelLarge     | 16 SemiBold, buttons                        |
/// | labelMedium    | 12 Medium, group labels above cards         |
/// | labelSmall     | 11 Regular, captions                        |
TextTheme buildMorrowTextTheme(MorrowColors c) {
  TextStyle s(
    double size,
    FontWeight weight,
    Color color, {
    double? height,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: morrowFontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  return TextTheme(
    headlineLarge: s(30, _semiBold, c.ink, height: 1.2, letterSpacing: -1),
    headlineMedium: s(27, _semiBold, c.ink, height: 1.2, letterSpacing: -0.8),
    headlineSmall: s(20, _semiBold, c.ink, height: 1.25),
    titleLarge: s(18, _semiBold, c.ink, height: 1.33),
    titleMedium: s(16, _semiBold, c.ink, height: 1.2, letterSpacing: -0.3),
    titleSmall: s(15, _semiBold, c.ink, height: 1.2),
    bodyLarge: s(15, _regular, c.ink, height: 1.45),
    bodyMedium: s(14, _regular, c.ink, height: 1.5),
    bodySmall: s(12, _regular, c.mutedText, height: 1.42),
    labelLarge: s(16, _semiBold, c.ink, height: 1.2),
    labelMedium: s(12, _medium, c.mutedText, height: 1.25),
    labelSmall: s(11, _regular, c.mutedText, height: 1.2),
  );
}

/// Styles with no matching Material role.
@immutable
class MorrowTextStyles extends ThemeExtension<MorrowTextStyles> {
  const MorrowTextStyles({
    required this.eyebrow,
    required this.statValue,
    required this.wordmark,
    required this.dayNumber,
  });

  factory MorrowTextStyles.from(MorrowColors c) {
    return MorrowTextStyles(
      eyebrow: TextStyle(
        fontFamily: morrowFontFamily,
        fontSize: 11,
        fontWeight: _semiBold,
        letterSpacing: 1.5,
        height: 1.2,
        color: c.primary,
      ),
      statValue: TextStyle(
        fontFamily: morrowFontFamily,
        fontSize: 20,
        fontWeight: _semiBold,
        letterSpacing: -0.4,
        height: 1.2,
        color: c.primary,
      ),
      wordmark: TextStyle(
        fontFamily: morrowFontFamily,
        fontSize: 23,
        fontWeight: _semiBold,
        letterSpacing: -1,
        height: 1.2,
        color: c.primary,
      ),
      dayNumber: TextStyle(
        fontFamily: morrowFontFamily,
        fontSize: 16,
        fontWeight: _semiBold,
        height: 1.2,
        color: c.ink,
      ),
    );
  }

  /// Small uppercase label above a page title, for example "ADD DETAILS".
  final TextStyle eyebrow;

  /// Large figure in a stat card.
  final TextStyle statValue;

  /// The "morrow" wordmark.
  final TextStyle wordmark;

  /// Date number in the week strip.
  final TextStyle dayNumber;

  static MorrowTextStyles of(BuildContext context) =>
      Theme.of(context).extension<MorrowTextStyles>()!;

  @override
  MorrowTextStyles copyWith({
    TextStyle? eyebrow,
    TextStyle? statValue,
    TextStyle? wordmark,
    TextStyle? dayNumber,
  }) {
    return MorrowTextStyles(
      eyebrow: eyebrow ?? this.eyebrow,
      statValue: statValue ?? this.statValue,
      wordmark: wordmark ?? this.wordmark,
      dayNumber: dayNumber ?? this.dayNumber,
    );
  }

  @override
  MorrowTextStyles lerp(MorrowTextStyles? other, double t) {
    if (other == null) return this;
    return MorrowTextStyles(
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
      statValue: TextStyle.lerp(statValue, other.statValue, t)!,
      wordmark: TextStyle.lerp(wordmark, other.wordmark, t)!,
      dayNumber: TextStyle.lerp(dayNumber, other.dayNumber, t)!,
    );
  }
}
