import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';

/// A rounded card holding rows separated by dividers, with an optional
/// group label above it (for example "Privacy" on Settings).
class CardGroup extends StatelessWidget {
  const CardGroup({required this.children, this.label, super.key});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider());
      rows.add(children[i]);
    }

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(MorrowRadii.lg),
        border: Border.all(color: colors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MorrowRadii.lg - 1),
        child: Material(
          type: MaterialType.transparency,
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ),
    );

    final groupLabel = label;
    if (groupLabel == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            groupLabel,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(height: MorrowSpacing.sm),
        card,
      ],
    );
  }
}
