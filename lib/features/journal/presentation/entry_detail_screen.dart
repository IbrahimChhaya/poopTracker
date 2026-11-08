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
import 'detail_labels.dart';
import 'widgets/stool_form_icon.dart';

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
    final display = ref.watch(displayProvider);

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
                    if (entry.hasTime)
                      Text(
                        formatTime(entry.localWallClock),
                        style: text.headlineMedium,
                      )
                    else
                      Text(
                        'No time recorded',
                        style: text.bodyLarge!.copyWith(
                          color: colors.mutedText,
                        ),
                      ),
                    if (display.showStoolForm && entry.stoolType != null) ...[
                      const SizedBox(height: MorrowSpacing.lg),
                      Container(
                        width: 90,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(MorrowRadii.lg),
                        ),
                        child: StoolFormIcon(type: entry.stoolType!, size: 52),
                      ),
                      const SizedBox(height: MorrowSpacing.md),
                      Text(
                        stoolFormLabel(entry.stoolType!),
                        textAlign: TextAlign.center,
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: MorrowSpacing.xs),
                      Text(
                        stoolForms[entry.stoolType!]!.description,
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (display.showContext) ..._contextDetails(context, entry),
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

/// Ease and context tags (4.8). Shown only when "A little context" is on.
List<Widget> _contextDetails(BuildContext context, Entry entry) {
  final colors = MorrowColors.of(context);
  final text = Theme.of(context).textTheme;
  const notRecorded = 'Not recorded';

  Widget chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(MorrowRadii.pill),
      border: Border.all(color: colors.line),
    ),
    child: Text(label, style: text.bodySmall!.copyWith(color: colors.ink)),
  );

  return [
    const SizedBox(height: MorrowSpacing.xl),
    Row(
      children: [
        Expanded(
          child: Text(
            'Ease of passage',
            style: text.bodyMedium!.copyWith(color: colors.mutedText),
          ),
        ),
        if (entry.ease != null) ...[
          ExcludeSemantics(
            child: Icon(
              Icons.check_circle_outline,
              size: 18,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          entry.ease == null ? notRecorded : easePhrase(entry.ease!),
          style: text.titleSmall!.copyWith(fontSize: 14),
        ),
      ],
    ),
    const SizedBox(height: MorrowSpacing.lg),
    const Divider(),
    const SizedBox(height: MorrowSpacing.lg),
    Semantics(header: true, child: Text('Context', style: text.titleMedium)),
    const SizedBox(height: MorrowSpacing.md),
    Wrap(
      spacing: MorrowSpacing.sm,
      runSpacing: MorrowSpacing.sm,
      children: entry.tags.isEmpty
          ? [Text(notRecorded, style: text.bodySmall)]
          : [for (final t in sortedTags(entry.tags)) chip(tagLabel(t))],
    ),
  ];
}
