import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/scope.dart';
import '../../../../core/clock.dart';
import '../../../../ui/format/labels.dart';
import '../../../../ui/theme/morrow_colors.dart';
import '../../../../ui/theme/morrow_tokens.dart';
import '../../../../ui/widgets/morrow_button.dart';
import '../../../../ui/widgets/morrow_chip.dart';
import '../../../../ui/widgets/overlays.dart';
import '../../../../ui/widgets/states.dart';
import '../../../settings/data/settings_repository.dart';
import '../../domain/entry.dart';
import '../detail_labels.dart';
import '../widgets/stool_form_icon.dart';
import 'entry_editor_controller.dart';
import 'entry_time_sheet.dart';

/// The optional steps of the add/edit flow, in order.
enum DetailStep { stoolForm, context }

/// Steps shown for the current settings. Empty when both are off.
List<DetailStep> enabledSteps(DisplaySettings s) => [
  if (s.showStoolForm) DetailStep.stoolForm,
  if (s.showContext) DetailStep.context,
];

const String _stepRouteName = 'entry-detail-step';

/// Opens [step] above the editor.
Future<void> openDetailStep(
  BuildContext context, {
  required EditorTarget target,
  required List<DetailStep> steps,
  required DetailStep step,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: _stepRouteName),
      builder: (_) => switch (step) {
        DetailStep.stoolForm => StoolFormStep(target: target, steps: steps),
        DetailStep.context => ContextStep(target: target, steps: steps),
      },
    ),
  );
}

/// Saves the draft and, on success, closes the steps and the editor.
Future<void> _saveAndClose(
  BuildContext context,
  WidgetRef ref,
  EditorTarget target,
) async {
  final outcome = await ref.read(entryEditorProvider(target).notifier).save();
  if (!context.mounted || outcome != SaveOutcome.saved) return;
  showMorrowToast(
    context,
    target.original == null ? 'Entry saved' : 'Changes saved',
  );
  final router = GoRouter.of(context);
  Navigator.of(context).popUntil((r) => r.settings.name != _stepRouteName);
  router.pop();
}

/// Moves on from [current]: to the next enabled step, or back to the editor.
void _next(
  BuildContext context,
  EditorTarget target,
  List<DetailStep> steps,
  DetailStep current,
) {
  final i = steps.indexOf(current);
  final nav = Navigator.of(context);
  if (i + 1 < steps.length) {
    nav.pushReplacement(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: _stepRouteName),
        builder: (_) => ContextStep(target: target, steps: steps),
      ),
    );
  } else {
    nav.pop();
  }
}

/// Title, optional back button, trailing action and the progress bar shared
/// by both steps. The bar shows how many steps there are (one bar per
/// enabled step) and where the user is.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.title,
    required this.index,
    required this.count,
    this.showBack = false,
    this.trailing,
  });

  final String title;
  final bool showBack;
  final int index;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (showBack) ...[
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                color: colors.ink,
              ),
              const SizedBox(width: MorrowSpacing.xs),
            ] else
              const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: text.headlineLarge),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: MorrowSpacing.md),
        Semantics(
          container: true,
          label: 'Step ${index + 1} of $count',
          excludeSemantics: true,
          child: Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= index ? colors.primary : colors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.children, required this.actions});

  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 24, 24),
                children: children,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.line)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indents step content to line up with the title (after the back button).
Widget _indent(Widget child) =>
    Padding(padding: const EdgeInsets.only(left: 12), child: child);

/// "What was the form?" (3.2).
class StoolFormStep extends ConsumerWidget {
  const StoolFormStep({required this.target, required this.steps, super.key});

  final EditorTarget target;
  final List<DetailStep> steps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(entryEditorProvider(target));
    final controller = ref.read(entryEditorProvider(target).notifier);
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final hasNext = steps.indexOf(DetailStep.stoolForm) + 1 < steps.length;
    final today = ref.watch(clockProvider).today();

    Future<void> chooseTime() async {
      final picked = await showEntryTimeSheet(
        context,
        initial: (
          date: s.date,
          hour: s.hour,
          minute: s.minute,
          hasTime: s.hasTime,
        ),
        today: today,
        isInFuture: controller.isInFuture,
      );
      if (picked != null) {
        controller.setDateTime(
          picked.date,
          picked.hour,
          picked.minute,
          hasTime: picked.hasTime,
        );
      }
    }

    return _StepScaffold(
      actions: [
        MorrowButton(
          label: hasNext ? 'Continue' : 'Done',
          onPressed: s.saving
              ? null
              : () => _next(context, target, steps, DetailStep.stoolForm),
        ),
      ],
      children: [
        _StepHeader(
          title: target.original == null ? 'New entry' : 'Edit entry',
          index: steps.indexOf(DetailStep.stoolForm),
          count: steps.length,
          trailing: TextButton(
            onPressed: () =>
                _next(context, target, steps, DetailStep.stoolForm),
            child: const Text('Skip'),
          ),
        ),
        const SizedBox(height: MorrowSpacing.lg),
        _indent(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.saveFailed) ...[
                const ErrorBanner(
                  title: 'Couldn’t save your entry',
                  message:
                      'Your draft is still here. Nothing has been lost. Try '
                      'again.',
                ),
                const SizedBox(height: MorrowSpacing.lg),
              ],
              _WhenSummary(
                label:
                    '${relativeDay(s.date, today: today)}, '
                    '${formatDayMonth(s.date)}',
                time: s.hasTime ? formatTime(s.wall) : 'No time',
                onTap: chooseTime,
              ),
              const SizedBox(height: MorrowSpacing.xxl),
              Semantics(
                header: true,
                child: Text('What was the form?', style: text.headlineSmall),
              ),
              const SizedBox(height: MorrowSpacing.xs),
              Text(
                'Choose the closest match',
                style: text.bodySmall!.copyWith(fontSize: 13),
              ),
              const SizedBox(height: MorrowSpacing.md),
              for (final type in stoolForms.keys) ...[
                _StoolOption(
                  type: type,
                  selected: s.details.stoolType == type,
                  onTap: () => controller.toggleStoolType(type),
                ),
                const SizedBox(height: MorrowSpacing.sm),
              ],
              const SizedBox(height: MorrowSpacing.sm),
              Text(
                'Bristol Stool Form Scale · Types describe form, not a '
                'diagnosis.',
                style: text.labelSmall!.copyWith(color: colors.mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhenSummary extends StatelessWidget {
  const _WhenSummary({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(MorrowRadii.md);
    return Semantics(
      button: true,
      label: 'When: $label, $time. Change',
      excludeSemantics: true,
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: colors.mutedIcon,
                ),
                const SizedBox(width: MorrowSpacing.sm),
                Expanded(child: Text(label, style: text.bodyMedium)),
                const SizedBox(width: MorrowSpacing.sm),
                Flexible(
                  child: Text(
                    time,
                    textAlign: TextAlign.end,
                    style: text.bodyMedium,
                  ),
                ),
                const SizedBox(width: MorrowSpacing.xs),
                Icon(Icons.expand_more, size: 18, color: colors.mutedIcon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoolOption extends StatelessWidget {
  const _StoolOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final int type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final form = stoolForms[type]!;
    final radius = BorderRadius.circular(MorrowRadii.md);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: 'Type $type, ${form.name}. ${form.description}',
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.tint : colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? colors.primary : colors.line),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(width: 48, child: StoolFormIcon(type: type, size: 44)),
                const SizedBox(width: MorrowSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$type · ${form.name}',
                        style: text.titleSmall!.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(form.description, style: text.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(width: MorrowSpacing.sm),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? colors.primary : colors.mutedIcon,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "A little context" (3.3). Says once, at the top, that it is all optional.
class ContextStep extends ConsumerStatefulWidget {
  const ContextStep({required this.target, required this.steps, super.key});

  final EditorTarget target;
  final List<DetailStep> steps;

  @override
  ConsumerState<ContextStep> createState() => _ContextStepState();
}

class _ContextStepState extends ConsumerState<ContextStep> {
  late final TextEditingController _note = TextEditingController(
    text: ref.read(entryEditorProvider(widget.target)).comment,
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final steps = widget.steps;
    final s = ref.watch(entryEditorProvider(target));
    final controller = ref.read(entryEditorProvider(target).notifier);
    final display = ref.watch(displayProvider);
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(clockProvider).today();
    final d = s.details;

    Widget section(String title, {String? hint, required List<Widget> chips}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: text.titleMedium),
                  ),
                ),
                if (hint != null) Text(hint, style: text.labelSmall),
              ],
            ),
            const SizedBox(height: MorrowSpacing.md),
            ChipWrap(children: chips),
            const SizedBox(height: MorrowSpacing.xxl),
          ],
        );

    final type = d.stoolType;
    return _StepScaffold(
      actions: [
        MorrowButton(
          label: target.original == null ? 'Save entry' : 'Save changes',
          busyLabel: 'Saving…',
          busy: s.saving,
          onPressed: () => _saveAndClose(context, ref, target),
        ),
      ],
      children: [
        _StepHeader(
          title: 'A little context',
          index: steps.indexOf(DetailStep.context),
          count: steps.length,
          showBack: true,
          trailing: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        ),
        const SizedBox(height: MorrowSpacing.lg),
        _indent(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.saveFailed) ...[
                const ErrorBanner(
                  title: 'Couldn’t save your entry',
                  message:
                      'Your draft is still here. Nothing has been lost. Try '
                      'again.',
                ),
                const SizedBox(height: MorrowSpacing.lg),
              ],
              if (display.showStoolForm && type != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.tint,
                    borderRadius: BorderRadius.circular(MorrowRadii.md),
                  ),
                  child: Row(
                    children: [
                      StoolFormIcon(type: type, size: 44),
                      const SizedBox(width: MorrowSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stoolFormLabel(type),
                              style: text.titleSmall!.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${relativeDay(s.date, today: today)}, '
                              '${formatDayMonth(s.date)}'
                              '${s.hasTime ? ' · ${formatTime(s.wall)}' : ''}',
                              style: text.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            settings: const RouteSettings(name: _stepRouteName),
                            builder: (_) =>
                                StoolFormStep(target: target, steps: steps),
                          ),
                        ),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MorrowSpacing.xxl),
              ],
              section(
                'How did it feel?',
                chips: [
                  for (final e in Ease.values)
                    MorrowChip(
                      label: easeChip(e),
                      selected: d.ease == e,
                      onSelected: (_) => controller.toggleEase(e),
                    ),
                ],
              ),
              section(
                'Anything to note?',
                hint: 'Choose all that apply',
                chips: [
                  for (final t in Tag.values)
                    MorrowChip(
                      label: tagLabel(t),
                      selected: d.tags.contains(t),
                      onSelected: (_) => controller.toggleTag(t),
                    ),
                ],
              ),
              Semantics(
                header: true,
                child: Text('Your notes', style: text.titleMedium),
              ),
              const SizedBox(height: MorrowSpacing.md),
              TextField(
                controller: _note,
                onChanged: controller.setComment,
                enabled: !s.saving,
                minLines: 3,
                maxLines: 8,
                maxLength: maxCommentLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Add a note…'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
