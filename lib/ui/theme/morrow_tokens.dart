import 'package:flutter/widgets.dart';

/// Corner radii from the Figma file.
abstract final class MorrowRadii {
  static const double sm = 12; // icon tiles
  static const double md = 14; // buttons, day cells, banners, toast
  static const double lg = 16; // setting cards, large primary action
  static const double xl = 18; // journal and empty-state cards
  static const double xxl = 20; // stat card, dialog
  static const double sheet = 28;
  static const double pill = 99; // chips, badges, nav indicator
}

/// Spacing on a 4 px grid, matching the Figma auto-layout values.
abstract final class MorrowSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Horizontal page padding.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: 24);
}

/// Fixed component sizes. Heights are minimums so content can grow with
/// large text.
abstract final class MorrowSizes {
  static const double buttonMinHeight = 52;
  static const double largeButtonMinHeight = 54;
  static const double iconTile = 36;
  static const double iconTileIcon = 20;
  static const double dayCellMinHeight = 72;

  /// Smallest tap target (Material and the accessibility brief).
  static const double minTouchTarget = 48;
}
