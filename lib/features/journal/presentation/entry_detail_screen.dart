import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paths.dart';
import '../../../app/scope.dart';
import '../../../ui/format/labels.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/states.dart';
import '../domain/entry.dart';
import 'delete_entry.dart';

/// "Entry details" (4.7). Closes itself if the entry no longer exists.
class EntryDetailScreen extends ConsumerWidget {
  const EntryDetailScreen({required this.entryId, super.key});

  final int? entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider);
    final Widget body = switch (entries) {
      AsyncData(:final value) => _body(context, ref, value),
      AsyncError() => const Padding(
        padding: EdgeInsets.all(24),
        child: ErrorBanner(
          title: 'Couldn’t open this entry',
          message: 'Nothing has been changed.',
        ),
      ),
      _ => const LoadingState(label: 'Loading…'),
    };
    return Scaffold(body: SafeArea(child: body));
  }

  Widget _body(BuildContext context, WidgetRef ref, List<Entry> entries) {
    final entry = entries.where((e) => e.id == entryId).firstOrNull;
    if (entry == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && context.canPop()) context.pop();
      });
      return const SizedBox.shrink();
    }
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final note = entry.comment;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 24, 24),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              color: colors.ink,
            ),
            const SizedBox(width: MorrowSpacing.xs),
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Entry details', style: text.headlineLarge),
              ),
            ),
            TextButton(
              onPressed: () =>
                  context.push(AppPaths.editEntry, extra: entry.id),
              child: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: MorrowSpacing.xl),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: colors.sand,
                  borderRadius: BorderRadius.circular(MorrowRadii.xxl),
                ),
                child: Column(
                  children: [
                    Text(
                      formatFullDate(entry.localDate).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: text.labelSmall!.copyWith(
                        color: colors.warmText,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: MorrowSpacing.sm),
                    Text(
                      formatTime(entry.localWallClock),
                      style: text.headlineMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MorrowSpacing.xxl),
              Text('Your notes', style: text.titleMedium),
              const SizedBox(height: MorrowSpacing.md),
              Container(
                padding: const EdgeInsets.all(MorrowSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(MorrowRadii.lg),
                  border: Border.all(color: colors.line),
                ),
                child: Text(
                  note ?? 'No note added.',
                  style: note == null
                      ? text.bodyMedium!.copyWith(color: colors.mutedText)
                      : text.bodyMedium,
                ),
              ),
              const SizedBox(height: MorrowSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: colors.mutedIcon,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Saved on this device · Not shared anywhere',
                      style: text.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MorrowSpacing.sm),
              Center(
                child: TextButton.icon(
                  onPressed: () =>
                      confirmAndDeleteEntry(context, ref, entry.id),
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete this entry'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
