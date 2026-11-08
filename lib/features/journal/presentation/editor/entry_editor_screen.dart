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
import 'detail_steps.dart';
import 'entry_editor_controller.dart';
import 'entry_time_sheet.dart';

/// "New entry" (2.2–2.6).
class NewEntryScreen extends StatelessWidget {
  const NewEntryScreen({this.initialDate, super.key});

  /// Default date for the entry (a past day selected on the journal home).
  final LocalDate? initialDate;

  @override
  Widget build(BuildContext context) =>
      EntryEditor(original: null, initialDate: initialDate);
}

/// "Edit entry" (4.9). Looks the entry up once by id; a later change to the
/// list never resets the draft.
class EditEntryScreen extends ConsumerStatefulWidget {
  const EditEntryScreen({required this.entryId, super.key});

  final int? entryId;

  @override
  ConsumerState<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends ConsumerState<EditEntryScreen> {
  Entry? _original;

  @override
  Widget build(BuildContext context) {
    final original = _original;
    if (original != null) return EntryEditor(original: original);

    final entries = ref.watch(entriesProvider);
    return switch (entries) {
      AsyncData(:final value) => _resolve(value),
      AsyncError() => const Scaffold(
        body: Center(
          child: ErrorBanner(
            title: 'Couldn’t open this entry',
            message: 'Nothing has been changed.',
          ),
        ),
      ),
      _ => const Scaffold(body: LoadingState(label: 'Loading…')),
    };
  }

  Widget _resolve(List<Entry> entries) {
    final found = entries.where((e) => e.id == widget.entryId).firstOrNull;
    if (found == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return const Scaffold();
    }
    _original = found;
    return EntryEditor(original: found);
  }
}

/// "Easy · Bloating · After a meal, Coffee", or "Not set".
String _contextSummary(EntryDetails d) {
  if (d.contextEmpty) return 'Not set';
  return [
    if (d.ease != null) easeChip(d.ease!),
    ?symptomSummary(d.symptoms),
    if (d.tags.isNotEmpty) sortedTags(d.tags).map(tagLabel).join(', '),
  ].join(' · ');
}

/// The editor itself, shared by new and edit.
class EntryEditor extends ConsumerStatefulWidget {
  const EntryEditor({required this.original, this.initialDate, super.key});

  final Entry? original;
  final LocalDate? initialDate;

  @override
  ConsumerState<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<EntryEditor> {
  late final TextEditingController _note = TextEditingController(
    text: widget.original?.comment ?? '',
  );

  bool get _editing => widget.original != null;

  EditorTarget get _target =>
      (original: widget.original, initialDate: widget.initialDate);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  EntryEditorController get _controller =>
      ref.read(entryEditorProvider(_target).notifier);

  Future<void> _chooseTime(EntryEditorState s) async {
    final picked = await showEntryTimeSheet(
      context,
      initial: (date: s.date, hour: s.hour, minute: s.minute),
      today: ref.read(clockProvider).today(),
      isInFuture: _controller.isInFuture,
    );
    if (picked != null) {
      _controller.setDateTime(picked.date, picked.hour, picked.minute);
    }
  }

  Future<void> _save() async {
    final outcome = await _controller.save();
    if (!mounted || outcome != SaveOutcome.saved) return;
    showMorrowToast(context, _editing ? 'Changes saved' : 'Entry saved');
    context.pop();
  }

  Future<bool> _confirmDiscard() => showMorrowConfirmDialog(
    context,
    title: _editing ? 'Discard your changes?' : 'Discard this entry?',
    message: _editing
        ? 'Your changes haven’t been saved. If you leave now, they will be '
              'lost.'
        : 'You haven’t saved it yet. If you leave now, what you’ve entered '
              'will be lost.',
    confirmLabel: _editing ? 'Discard changes' : 'Discard',
    cancelLabel: 'Keep editing',
    destructive: true,
  );

  Future<void> _close() async {
    final s = ref.read(entryEditorProvider(_target));
    if (s.saving) return;
    if (!s.hasChanges || await _confirmDiscard()) {
      if (mounted) context.pop();
    }
  }

  Future<void> _delete() async {
    final deleted = await confirmAndDeleteEntry(
      context,
      ref,
      widget.original!.id,
    );
    if (deleted && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(entryEditorProvider(_target));
    final display = ref.watch(displayProvider);
    final steps = enabledSteps(display);
    // The note can also be edited on the context step; keep this field in
    // step with the draft.
    ref.listen(entryEditorProvider(_target).select((s) => s.comment), (_, c) {
      if (_note.text != c) _note.text = c;
    });
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(clockProvider).today();
    final whenLabel =
        '${relativeDay(s.date, today: today)}, ${formatTime(s.wall)}';

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
                              _editing ? 'Edit entry' : 'New entry',
                              style: text.headlineSmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MorrowSpacing.xxl),
                    if (s.saveFailed) ...[
                      const ErrorBanner(
                        title: 'Couldn’t save your entry',
                        message:
                            'Your draft is still here. Nothing has been lost. '
                            'Try again.',
                      ),
                      const SizedBox(height: MorrowSpacing.xxl),
                    ],
                    CardGroup(
                      children: [
                        SettingRow.navigation(
                          icon: Icons.schedule_outlined,
                          title: 'When',
                          subtitle: whenLabel,
                          onTap: () => _chooseTime(s),
                        ),
                      ],
                    ),
                    if (steps.isNotEmpty) ...[
                      const SizedBox(height: MorrowSpacing.xxl),
                      CardGroup(
                        label: 'Optional details',
                        children: [
                          if (display.showStoolForm)
                            SettingRow.navigation(
                              icon: Icons.notes,
                              title: 'Stool form',
                              subtitle: s.details.stoolType == null
                                  ? 'Not set'
                                  : stoolFormLabel(s.details.stoolType!),
                              onTap: () => openDetailStep(
                                context,
                                target: _target,
                                steps: steps,
                                step: DetailStep.stoolForm,
                              ),
                            ),
                          if (display.showContext)
                            SettingRow.navigation(
                              icon: Icons.monitor_heart_outlined,
                              title: 'A little context',
                              subtitle: _contextSummary(s.details),
                              onTap: () => openDetailStep(
                                context,
                                target: _target,
                                steps: steps,
                                step: DetailStep.context,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: MorrowSpacing.xxl),
                    Text('Note (optional)', style: text.labelMedium),
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
                    if (_editing) ...[
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
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.line)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MorrowButton(
                        label: s.saveFailed
                            ? 'Try again'
                            : _editing
                            ? 'Save changes'
                            : 'Save entry',
                        busyLabel: 'Saving…',
                        busy: s.saving,
                        onPressed: _save,
                      ),
                      if (_editing) ...[
                        const SizedBox(height: MorrowSpacing.md),
                        MorrowButton(
                          label: 'Cancel',
                          variant: MorrowButtonVariant.secondary,
                          onPressed: s.saving ? null : _close,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
