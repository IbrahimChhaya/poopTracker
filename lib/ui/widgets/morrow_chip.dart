import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';

/// A selectable chip, as used on the "A little context" step.
///
/// The selected state is shown by a check mark and bolder text as well as
/// colour, and is exposed to screen readers by [FilterChip].
class MorrowChip extends StatelessWidget {
  const MorrowChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final base = Theme.of(context).textTheme.bodySmall!;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      labelStyle: selected
          ? base.copyWith(color: colors.primary, fontWeight: FontWeight.w600)
          : base.copyWith(color: colors.ink),
    );
  }
}

/// Lays chips out in wrapping rows with the Figma spacing.
class ChipWrap extends StatelessWidget {
  const ChipWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MorrowSpacing.sm,
      runSpacing: MorrowSpacing.sm,
      children: children,
    );
  }
}
