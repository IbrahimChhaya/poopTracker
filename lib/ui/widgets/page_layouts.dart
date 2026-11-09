import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';
import '../theme/morrow_typography.dart';
import 'back_header.dart';
import 'icon_tile.dart';

/// The bar of full-width buttons at the bottom of a page.
class ActionBar extends StatelessWidget {
  const ActionBar({required this.actions, super.key});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: MorrowSpacing.md),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A Settings sub-page: back button and title, scrolling content, and
/// optional buttons pinned at the bottom (above the keyboard).
class SubPage extends StatelessWidget {
  const SubPage({
    required this.title,
    required this.children,
    this.actions = const [],
    super.key,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // Above 130% text a pinned footer would take too much of the screen,
    // so the buttons scroll at the end of the page instead.
    final unpinned = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  BackHeader(title: title),
                  const SizedBox(height: MorrowSpacing.xxl),
                  ...children,
                  if (unpinned && actions.isNotEmpty) ...[
                    const SizedBox(height: MorrowSpacing.xxl),
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: MorrowSpacing.md),
                      actions[i],
                    ],
                  ],
                ],
              ),
            ),
            if (!unpinned && actions.isNotEmpty) ActionBar(actions: actions),
          ],
        ),
      ),
    );
  }
}

/// The look of a status icon in [StatusPage].
enum StatusBadge { busy, done, problem }

/// A full-page status ("Creating your backup…", "Backup saved"): the
/// morrow wordmark, a centred badge, a title and message, and optional
/// buttons. The title is announced when the page appears.
class StatusPage extends StatelessWidget {
  const StatusPage({
    required this.badge,
    required this.title,
    required this.message,
    this.below,
    this.actions = const [],
    super.key,
  });

  final StatusBadge badge;
  final String title;
  final String message;

  /// Shown under the message, for example a warning card.
  final Widget? below;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final Widget icon = switch (badge) {
      StatusBadge.busy => const SizedBox.square(
        dimension: 40,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
      StatusBadge.done => _Circle(
        background: colors.tint,
        child: Icon(Icons.check, color: colors.primary),
      ),
      StatusBadge.problem => _Circle(
        background: colors.sand,
        child: Icon(Icons.error_outline, color: colors.danger),
      ),
    };
    final extra = below;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.spa_outlined,
                          color: colors.primary,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'morrow',
                          style: MorrowTextStyles.of(context).wordmark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 120),
                  Center(child: ExcludeSemantics(child: icon)),
                  const SizedBox(height: MorrowSpacing.lg),
                  // Title and message are announced together ("Restore
                  // complete. 1 entry added…").
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Column(
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: text.headlineSmall,
                          ),
                        ),
                        const SizedBox(height: MorrowSpacing.sm),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: text.bodyMedium!.copyWith(
                            color: colors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (extra != null) ...[
                    const SizedBox(height: MorrowSpacing.lg),
                    extra,
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ActionBar(actions: actions),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: child,
  );
}

/// An icon, title and subtitle row with no action, inside a CardGroup.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MorrowSpacing.lg,
          vertical: 14,
        ),
        child: Row(
          children: [
            ExcludeSemantics(child: IconTile(icon: icon)),
            const SizedBox(width: MorrowSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: MorrowSpacing.xxs),
                  Text(
                    subtitle,
                    style: text.bodySmall!.copyWith(color: colors.mutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
