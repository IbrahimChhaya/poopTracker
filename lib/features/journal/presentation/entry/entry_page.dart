import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/scope.dart';
import '../../../../core/clock.dart';
import '../../../../core/time/local_date.dart';
import '../../../../ui/format/labels.dart';
import '../../../../ui/theme/morrow_colors.dart';
import '../../../../ui/theme/morrow_tokens.dart';
import '../../../../ui/widgets/card_group.dart';
import '../../../../ui/widgets/morrow_button.dart';
import '../../../../ui/widgets/overlays.dart';
import '../../../../ui/widgets/setting_row.dart';
import '../../../../ui/widgets/states.dart';
import '../../domain/entry.dart';
import '../delete_entry.dart';
import '../detail_labels.dart';
import 'details_sheet.dart';
import 'entry_page_controller.dart';
import 'entry_time_sheet.dart';
import 'quick_add.dart';

/// The entry page (2.2–2.7, 3.1–3.4, 4.7–4.9): one page to view and change
/// an entry, opened right after "Add an entry" and from any list. Reads the
/// entry once when it opens; closes itself if the entry no longer exists.
class EntryPage extends ConsumerWidget {
  const EntryPage({required this.route, super.key});

  /// Null when the route data is missing (for example after the OS restored
  /// the app), in which case the page closes itself.
  final EntryRoute? route;

  void _leave(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && context.canPop()) context.pop();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = route;
    if (r == null) {
      _leave(context);
      return const Scaffold();
    }
    final entry = ref.watch(entryByIdProvider(r.id));
    if (entry case AsyncData(value: null)) {
      _leave(context);
      return const Scaffold();
    }
    return switch (entry) {
      AsyncData(value: final Entry e) => _EntryPageBody(
        target: (entry: e, isNew: r.isNew),
      ),
      AsyncError() => const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: ErrorBanner(
              title: 'Couldn’t open this entry',
              message: 'Nothing has been changed.',
            ),
          ),
        ),
      ),
      _ => const Scaffold(body: LoadingState(label: 'Loading…')),
    };
  }
}

/// "Today’s entry", "Wednesday’s entry", or "Entry" for anything older than
/// a week.
String entryPageTitle(LocalDate day, {required LocalDate today}) {
  final ago = day.daysUntil(today);
  if (ago < 0 || ago >= 7) return 'Entry';
  return '${relativeDay(day, today: today)}’s entry';
}

/// "Today · 1:35 pm", "Yesterday · No time", "Wednesday 28 Oct · 9:00 am".
String entryWhenLabel(
  LocalDate day,
  DateTime? wall, {
  required LocalDate today,
}) {
  final ago = day.daysUntil(today);
  final dayLabel = ago >= 0 && ago < 7
      ? relativeDay(day, today: today)
      : '${weekdayName(day)} '
            '${formatDayMonth(day, withYear: day.year != today.year)}';
  return '$dayLabel · ${wall == null ? 'No time' : formatTime(wall)}';
}

/// "Added to today", "Added to yesterday", "Added to Wednesday".
String addedToLabel(LocalDate day, {required LocalDate today}) {
  final ago = day.daysUntil(today);
  final relative = relativeDay(day, today: today);
  return 'Added to ${ago == 0 || ago == 1 ? relative.toLowerCase() : relative}';
}

/// "Easy · After a meal, Coffee", or "Not added".
String contextSummary(EntryDetails d) {
  if (d.contextEmpty) return 'Not added';
  return [
    if (d.ease != null) easeChip(d.ease!),
    if (d.tags.isNotEmpty) sortedTags(d.tags).map(tagLabel).join(', '),
  ].join(' · ');
}

class _EntryPageBody extends ConsumerStatefulWidget {
  const _EntryPageBody({required this.target});

  final EntryTarget target;

  @override
  ConsumerState<_EntryPageBody> createState() => _EntryPageBodyState();
}

class _EntryPageBodyState extends ConsumerState<_EntryPageBody> {
  late final TextEditingController _note = TextEditingController(
    text: widget.target.entry.comment ?? '',
  );

  EntryTarget get _target => widget.target;

  EntryPageController get _controller =>
      ref.read(entryPageProvider(_target).notifier);

  @override
  void initState() {
    super.initState();
    // A toast from the journal ("Changes saved") would otherwise float over
    // this page's Save bar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _chooseTime(EntryPageState s) async {
    final picked = await showEntryTimeSheet(
      context,
      initial: (
        date: s.date,
        hour: s.hour,
        minute: s.minute,
        hasTime: s.hasTime,
      ),
      today: ref.read(clockProvider).today(),
      isInFuture: _controller.isInFuture,
    );
    if (picked != null) {
      _controller.setDateTime(
        picked.date,
        picked.hour,
        picked.minute,
        hasTime: picked.hasTime,
      );
    }
  }

  Future<void> _save() async {
    final outcome = await _controller.save();
    if (!mounted || outcome != SaveOutcome.saved) return;
    showMorrowToast(context, 'Changes saved');
    context.pop();
  }

  /// "Discard changes?" (2.7). The entry itself is already saved.
  Future<bool> _confirmDiscard() => showMorrowConfirmDialog(
    context,
    title: 'Discard changes?',
    message:
        'Your entry is already saved. Only the changes you just made to it '
        'will be lost.',
    confirmLabel: 'Discard changes',
    cancelLabel: 'Keep editing',
    destructive: true,
  );

  Future<void> _close() async {
    final s = ref.read(entryPageProvider(_target));
    if (s.saving) return;
    if (!s.hasChanges || await _confirmDiscard()) {
      if (mounted) context.pop();
    }
  }

  /// Undo for a just-added entry (2.2, 2.11). Asks first once anything has
  /// been changed.
  Future<void> _undo() async {
    if (_controller.edited) {
      final confirmed = await showMorrowConfirmDialog(
        context,
        title: 'Undo this entry?',
        message: 'It will be removed, along with the changes you just made.',
        confirmLabel: 'Undo entry',
        cancelLabel: 'Keep entry',
        destructive: true,
        dangerFilled: true,
      );
      if (!confirmed || !mounted) return;
    }
    final undone = await _controller.undo();
    if (!mounted) return;
    if (!undone) {
      showMorrowToast(context, 'Couldn’t undo. Your entry is still saved.');
      return;
    }
    showMorrowToast(context, 'Entry removed');
    context.pop();
  }

  Future<void> _delete() async {
    final deleted = await confirmAndDeleteEntry(context, ref, _target.entry.id);
    if (deleted && mounted) context.pop();
  }

  void _openDetails(List<DetailPage> pages, DetailPage page) {
    showDetailsSheet(context, target: _target, pages: pages, initial: page);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(entryPageProvider(_target));
    final display = ref.watch(displayProvider);
    final pages = enabledDetailPages(display);
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(clockProvider).today();
    final isNew = _target.isNew;

    return PopScope(
      canPop: !s.hasChanges && !s.saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  children: [
                    Row(
                      children: [
                        IconButton.outlined(
                          onPressed: _close,
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
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
                              entryPageTitle(s.saved.localDate, today: today),
                              style: text.headlineSmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MorrowSpacing.xxl),
                    if (isNew) ...[
                      _AddedBanner(
                        label: addedToLabel(s.saved.localDate, today: today),
                        onUndo: s.saving ? null : _undo,
                      ),
                      const SizedBox(height: MorrowSpacing.xxl),
                    ],
                    if (s.saveFailed) ...[
                      const ErrorBanner(
                        title: 'Couldn’t save your changes',
                        message:
                            'Your changes are still here. Nothing has been '
                            'lost. Try again.',
                      ),
                      const SizedBox(height: MorrowSpacing.xxl),
                    ],
                    CardGroup(
                      children: [
                        SettingRow.navigation(
                          icon: Icons.schedule_outlined,
                          title: 'When',
                          subtitle: entryWhenLabel(
                            s.date,
                            s.hasTime ? s.wall : null,
                            today: today,
                          ),
                          actionLabel: 'Change',
                          onTap: () => _chooseTime(s),
                        ),
                      ],
                    ),
                    if (display.showContext) ...[
                      const SizedBox(height: MorrowSpacing.md),
                      CardGroup(
                        children: [
                          SettingRow.navigation(
                            icon: Icons.notes,
                            title: 'Context',
                            subtitle: contextSummary(s.details),
                            onTap: () =>
                                _openDetails(pages, DetailPage.context),
                          ),
                        ],
                      ),
                    ],
                    if (display.showStoolForm) ...[
                      const SizedBox(height: MorrowSpacing.md),
                      CardGroup(
                        children: [
                          SettingRow.navigation(
                            icon: Icons.notes,
                            title: 'Stool form',
                            subtitle: s.details.stoolType == null
                                ? 'Not added'
                                : stoolFormLabel(s.details.stoolType!),
                            onTap: () =>
                                _openDetails(pages, DetailPage.stoolForm),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: MorrowSpacing.xxl),
                    Text('Note', style: text.labelMedium),
                    const SizedBox(height: MorrowSpacing.sm),
                    TextField(
                      controller: _note,
                      onChanged: _controller.setComment,
                      enabled: !s.saving,
                      minLines: 4,
                      maxLines: 10,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: maxCommentLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      decoration: const InputDecoration(
                        hintText: 'Add a note…',
                      ),
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) => Text(
                            '$currentLength / $maxLength',
                            style: text.labelSmall,
                            semanticsLabel:
                                '$currentLength of $maxLength characters',
                          ),
                    ),
                    if (s.errors.contains(EntryValidationError.inFuture))
                      Padding(
                        padding: const EdgeInsets.only(top: MorrowSpacing.md),
                        child: Text(
                          'That time hasn’t happened yet. Choose an earlier '
                          'time.',
                          style: text.bodySmall!.copyWith(color: colors.danger),
                        ),
                      ),
                    // A just-added entry is removed with Undo instead.
                    if (!isNew) ...[
                      const SizedBox(height: MorrowSpacing.xl),
                      Center(
                        child: TextButton.icon(
                          onPressed: s.saving ? null : _delete,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.danger,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete this entry'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _SaveBar(state: s, onSave: _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Added to today" with Undo, shown until the page is left.
class _AddedBanner extends StatelessWidget {
  const _AddedBanner({required this.label, required this.onUndo});

  final String label;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(MorrowRadii.md),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.check, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                label,
                style: text.bodyMedium!.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          TextButton(onPressed: onUndo, child: const Text('Undo')),
        ],
      ),
    );
  }
}

/// The bottom bar: "Saved" (disabled, with a tick) until the date, time or
/// note changes, then "Save" with "Unsaved changes" above it (2.2, 2.5, 2.6).
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.state, required this.onSave});

  final EntryPageState state;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final s = state;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (s.hasChanges) ...[
              Text(
                s.saveFailed ? 'Not saved yet' : 'Unsaved changes',
                style: text.labelSmall,
              ),
              const SizedBox(height: MorrowSpacing.sm),
            ],
            MorrowButton(
              label: !s.hasChanges
                  ? 'Saved'
                  : s.saveFailed
                  ? 'Try again'
                  : 'Save',
              icon: s.hasChanges ? null : Icons.check,
              busyLabel: 'Saving…',
              busy: s.saving,
              onPressed: s.hasChanges ? onSave : null,
            ),
          ],
        ),
      ),
    );
  }
}
