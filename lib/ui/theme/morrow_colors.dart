import 'package:flutter/material.dart';

/// Raw light palette, taken from the morrow Figma file.
///
/// Widgets must not use these directly. Read colours from the theme instead
/// ([ColorScheme] or [MorrowColors]) so a dark palette can be added after v1.
abstract final class MorrowPalette {
  static const background = Color(0xFFF7F4EC);
  static const card = Color(0xFFFFFDF8);
  static const line = Color(0xFFDDDCD0);
  static const ink = Color(0xFF293B34);

  /// Secondary text. Darker than the Figma muted (#74796d) so body text
  /// meets 4.5:1 on background, card and tint.
  static const mutedText = Color(0xFF666B60);

  /// Icons, chevrons and other non-text marks (3:1 is enough for these).
  static const mutedIcon = Color(0xFF74796D);
  static const primary = Color(0xFF3D6552);
  static const tint = Color(0xFFE7EDE2);

  /// Secondary text on a primary-filled surface (the selected week day).
  static const onPrimaryMuted = Color(0xFFDCE6DC);

  /// Divider used on tint surfaces (for example the stat card).
  static const tintLine = Color(0xFFCCD5C7);
  static const sand = Color(0xFFF2E6DA);

  /// Warm icon colour used on sand tiles.
  static const warmIcon = Color(0xFFAC7157);
  static const danger = Color(0xFF8A4A32);
  static const switchTrackOff = Color(0xFFC9CDC1);
  static const disabledSurface = Color(0xFFDCDCD2);

  /// Label on [disabledSurface], for example "Saving…". Darker than the
  /// Figma muted so the busy label stays readable (4.6:1).
  static const disabledText = Color(0xFF595E53);
}

/// Colours that have no good home in [ColorScheme].
@immutable
class MorrowColors extends ThemeExtension<MorrowColors> {
  const MorrowColors({
    required this.background,
    required this.card,
    required this.line,
    required this.ink,
    required this.mutedText,
    required this.mutedIcon,
    required this.primary,
    required this.onPrimary,
    required this.onPrimaryMuted,
    required this.tint,
    required this.tintLine,
    required this.sand,
    required this.warmIcon,
    required this.danger,
    required this.switchTrackOff,
    required this.disabledSurface,
    required this.disabledText,
  });

  static const light = MorrowColors(
    background: MorrowPalette.background,
    card: MorrowPalette.card,
    line: MorrowPalette.line,
    ink: MorrowPalette.ink,
    mutedText: MorrowPalette.mutedText,
    mutedIcon: MorrowPalette.mutedIcon,
    primary: MorrowPalette.primary,
    onPrimary: MorrowPalette.card,
    onPrimaryMuted: MorrowPalette.onPrimaryMuted,
    tint: MorrowPalette.tint,
    tintLine: MorrowPalette.tintLine,
    sand: MorrowPalette.sand,
    warmIcon: MorrowPalette.warmIcon,
    danger: MorrowPalette.danger,
    switchTrackOff: MorrowPalette.switchTrackOff,
    disabledSurface: MorrowPalette.disabledSurface,
    disabledText: MorrowPalette.disabledText,
  );

  final Color background;
  final Color card;
  final Color line;
  final Color ink;
  final Color mutedText;
  final Color mutedIcon;
  final Color primary;
  final Color onPrimary;
  final Color onPrimaryMuted;
  final Color tint;
  final Color tintLine;
  final Color sand;
  final Color warmIcon;
  final Color danger;
  final Color switchTrackOff;
  final Color disabledSurface;
  final Color disabledText;

  /// The [MorrowColors] for [context]. The morrow theme always provides one.
  static MorrowColors of(BuildContext context) =>
      Theme.of(context).extension<MorrowColors>()!;

  @override
  MorrowColors copyWith({
    Color? background,
    Color? card,
    Color? line,
    Color? ink,
    Color? mutedText,
    Color? mutedIcon,
    Color? primary,
    Color? onPrimary,
    Color? onPrimaryMuted,
    Color? tint,
    Color? tintLine,
    Color? sand,
    Color? warmIcon,
    Color? danger,
    Color? switchTrackOff,
    Color? disabledSurface,
    Color? disabledText,
  }) {
    return MorrowColors(
      background: background ?? this.background,
      card: card ?? this.card,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      mutedText: mutedText ?? this.mutedText,
      mutedIcon: mutedIcon ?? this.mutedIcon,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      onPrimaryMuted: onPrimaryMuted ?? this.onPrimaryMuted,
      tint: tint ?? this.tint,
      tintLine: tintLine ?? this.tintLine,
      sand: sand ?? this.sand,
      warmIcon: warmIcon ?? this.warmIcon,
      danger: danger ?? this.danger,
      switchTrackOff: switchTrackOff ?? this.switchTrackOff,
      disabledSurface: disabledSurface ?? this.disabledSurface,
      disabledText: disabledText ?? this.disabledText,
    );
  }

  @override
  MorrowColors lerp(MorrowColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MorrowColors(
      background: l(background, other.background),
      card: l(card, other.card),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      mutedText: l(mutedText, other.mutedText),
      mutedIcon: l(mutedIcon, other.mutedIcon),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      onPrimaryMuted: l(onPrimaryMuted, other.onPrimaryMuted),
      tint: l(tint, other.tint),
      tintLine: l(tintLine, other.tintLine),
      sand: l(sand, other.sand),
      warmIcon: l(warmIcon, other.warmIcon),
      danger: l(danger, other.danger),
      switchTrackOff: l(switchTrackOff, other.switchTrackOff),
      disabledSurface: l(disabledSurface, other.disabledSurface),
      disabledText: l(disabledText, other.disabledText),
    );
  }
}
