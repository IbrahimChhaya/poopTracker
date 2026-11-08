import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';

/// The round back button and title at the top of a Settings sub-page.
class BackHeader extends StatelessWidget {
  const BackHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    return Row(
      children: [
        IconButton.outlined(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            side: BorderSide(color: colors.line),
            backgroundColor: colors.card,
            foregroundColor: colors.ink,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: MorrowSpacing.md),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
      ],
    );
  }
}
