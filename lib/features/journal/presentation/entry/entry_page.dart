import 'dart:async';

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
      AsyncError() => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton.outlined(
                  onPressed: () => context.pop(),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
                const SizedBox(height: MorrowSpacing.xxl),
                const ErrorBanner(
                  title: 'Couldn’t open this entry',
                  message: 'Nothing has been changed. Close it and try again.',
                ),
              ],
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

  /// Saves the note the moment the app leaves the foreground, before it can
  /// lock.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onInactive: () => unawaited(_controller.save()),
    onHide: () => unawaited(_controller.save()),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    // A toast from the journal ("Changes saved") would otherwise float over
    // this page's Save bar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
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

  bool _leaving = false;

  /// Done, ×, or system back: saves anything still waiting, then returns
  /// to the journal. If that save fails, the page stays with Try again.
  Future<void> _done() async {
    if (_leaving) return;
    _leaving = true;
    final ok = await _controller.flush();
    _leaving = false;
    if (!mounted || !ok) return;
    if (_controller.edited) showMorrowToast(context, 'Changes saved');
    context.pop();
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
    _controller.cancelAutosave();
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
        if (!didPop) _done();
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
                          onPressed: _done,
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
                              entryPageTitle(s.date, today: today),
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
                    if (s.errors.contains(EntryValidationError.inFuture))
                      Padding(
                        padding: const EdgeInsets.only(top: MorrowSpacing.md),
                        child: Text(
                          'That time hasn’t happened yet. Choose an earlier '
                          'time.',
                          style: text.bodySmall!.copyWith(color: colors.danger),
                        ),
                      ),
                    if (display.showContext) ...[
                      const SizedBox(height: MorrowSpacing.md),
                      CardGroup(
                        children: [
                          SettingRow.navigation(
                            icon: Icons.tune,
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
              _SaveBar(
                state: s,
                onDone: _done,
                onRetry: () => unawaited(_controller.save()),
              ),
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

/// The bottom bar (2.2, 2.5, 2.6): "Done", with the save status above it:
/// "Saved", "Saving…", or after a failure "Not saved yet" and Try again.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.state,
    required this.onDone,
    required this.onRetry,
  });

  final EntryPageState state;
  final VoidCallback onDone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final s = state;
    final status = s.saveFailed
        ? 'Not saved yet'
        : s.saving || s.hasChanges
        ? 'Saving…'
        : 'Saved';
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Announced only when it matters: a failed save.
            Semantics(
              liveRegion: s.saveFailed,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (status == 'Saved') ...[
                    ExcludeSemantics(
                      child: Icon(Icons.check, size: 14, color: colors.primary),
                    ),
                    const SizedBox(width: MorrowSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: text.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MorrowSpacing.sm),
            MorrowButton(
              label: s.saveFailed ? 'Try again' : 'Done',
              onPressed: s.saveFailed ? onRetry : onDone,
            ),
          ],
        ),
      ),
    );
  }
}
