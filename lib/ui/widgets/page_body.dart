import 'package:flutter/material.dart';

import '../theme/morrow_tokens.dart';
import '../theme/morrow_typography.dart';

/// Scrollable page content under a page title, as on the top-level tabs.
class PageBody extends StatelessWidget {
  const PageBody({
    required this.title,
    required this.children,
    this.wordmarkTitle = false,
    super.key,
  });

  final String title;
  final List<Widget> children;

  /// Shows [title] in the "morrow" wordmark style (journal home).
  final bool wordmarkTitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: wordmarkTitle
                  ? MorrowTextStyles.of(context).wordmark
                  : Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: MorrowSpacing.xxl),
          ...children,
        ],
      ),
    );
  }
}
