import 'package:flutter/material.dart';

import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/page_layouts.dart';

/// One welcome or tour page (1.1–1.5): a top row, a stage that fills the
/// free space, then the headline and one line, above a pinned button. At
/// large text the page scrolls under the button (1.3c).
class OnboardingLayout extends StatelessWidget {
  const OnboardingLayout({
    required this.top,
    required this.stage,
    required this.title,
    required this.body,
    required this.actions,
    super.key,
  });

  final Widget top;
  final Widget stage;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 20,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          top,
                          const SizedBox(height: MorrowSpacing.md),
                          Expanded(child: stage),
                          const SizedBox(height: 32),
                          Semantics(
                            header: true,
                            child: Text(title, style: text.headlineMedium),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            body,
                            style: text.bodyLarge!.copyWith(
                              color: colors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ActionBar(actions: actions),
          ],
        ),
      ),
    );
  }
}

/// A stage holding real controls (the switches on 1.3, app lock on 1.5).
/// Unlike a preview it scales with text and is read by screen readers.
class LiveStage extends StatelessWidget {
  const LiveStage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }
}
