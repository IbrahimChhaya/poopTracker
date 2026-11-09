import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';

enum IconTileTone { neutral, warm }

/// The small rounded square behind a row icon. Decorative: the row's text
/// carries the meaning, so the icon is excluded from semantics.
class IconTile extends StatelessWidget {
  const IconTile({
    required this.icon,
    this.tone = IconTileTone.neutral,
    super.key,
  });

  final IconData icon;
  final IconTileTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final (background, foreground) = switch (tone) {
      IconTileTone.neutral => (colors.tint, colors.primary),
      IconTileTone.warm => (colors.sand, colors.warmIcon),
    };
    return ExcludeSemantics(
      child: Container(
        width: MorrowSizes.iconTile,
        height: MorrowSizes.iconTile,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(MorrowRadii.sm),
        ),
        child: Icon(icon, size: MorrowSizes.iconTileIcon, color: foreground),
      ),
    );
  }
}
