import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';

/// "Nothing here yet" card for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(MorrowRadii.xl),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.titleMedium!.copyWith(letterSpacing: 0),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Inline error, for example "Couldn't save your entry".
///
/// It is a live region so screen readers announce it when it appears. The
/// alert icon and title mean it is not signalled by colour alone.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.sand,
          borderRadius: BorderRadius.circular(MorrowRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.error_outline, size: 20, color: colors.danger),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: text.titleSmall!.copyWith(
                      fontSize: 14,
                      color: colors.danger,
                    ),
                  ),
                  const SizedBox(height: MorrowSpacing.xxs),
                  Text(
                    message,
                    style: text.bodyMedium!.copyWith(
                      fontSize: 13,
                      height: 1.46,
                    ),
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

/// Centred spinner with a label, for example "Deleting data…".
class LoadingState extends StatelessWidget {
  const LoadingState({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(MorrowSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: MorrowSpacing.lg),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A calm, neutral note that isn't an error, for example "Keep your
/// passphrase safe" after a backup is saved. Sage Tint, an info icon and an
/// Ink title; not announced on arrival.
class NoticeCard extends StatelessWidget {
  const NoticeCard({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.tint,
          borderRadius: BorderRadius.circular(MorrowRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.info_outline, size: 20, color: colors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.titleSmall),
                  const SizedBox(height: MorrowSpacing.xxs),
                  Text(message, style: text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
