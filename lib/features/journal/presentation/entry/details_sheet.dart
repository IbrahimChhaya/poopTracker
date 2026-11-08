import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../ui/theme/morrow_colors.dart';
import '../../../../ui/theme/morrow_tokens.dart';
import '../../../../ui/widgets/morrow_button.dart';
import '../../../../ui/widgets/morrow_chip.dart';
import '../../../../ui/widgets/morrow_segmented.dart';
import '../../../../ui/widgets/states.dart';
import '../../../settings/data/settings_repository.dart';
import '../../domain/entry.dart';
import '../detail_labels.dart';
import '../widgets/stool_form_icon.dart';
import 'entry_page_controller.dart';

/// The pages of the details sheet, in order: Context, then Stool form.
enum DetailPage { context, stoolForm }

/// Pages shown for the current settings. Empty when both are off.
List<DetailPage> enabledDetailPages(DisplaySettings s) => [
  if (s.showContext) DetailPage.context,
  if (s.showStoolForm) DetailPage.stoolForm,
];

/// Tags on the Context page, in two short rows.
const List<Tag> _foodAndDrink = [Tag.afterMeal, Tag.coffee, Tag.lowFluids];
const List<Tag> _bodyAndMind = [
  Tag.stress,
  Tag.medication,
  Tag.onPeriod,
  Tag.feelingSick,
];

/// Opens the details sheet (3.2, 3.3, 3.6) on [initial]. Choices are stored
/// as they are made, so closing the sheet any way keeps them.
Future<void> showDetailsSheet(
  BuildContext context, {
  required EntryTarget target,
  required List<DetailPage> pages,
  required DetailPage initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _DetailsSheet(target: target, pages: pages, initial: initial),
  );
}

class _DetailsSheet extends ConsumerStatefulWidget {
  const _DetailsSheet({
    required this.target,
    required this.pages,
    required this.initial,
  });

  final EntryTarget target;
  final List<DetailPage> pages;
  final DetailPage initial;

  @override
  ConsumerState<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends ConsumerState<_DetailsSheet> {
  late int _index = math.max(0, widget.pages.indexOf(widget.initial));
  late final PageController _pager = PageController(initialPage: _index);

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  bool get _last => _index == widget.pages.length - 1;

  void _next() {
    if (_last) {
      Navigator.of(context).pop();
    } else {
      _pager.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final pages = widget.pages;
    final failed = ref.watch(
      entryPageProvider(widget.target).select((s) => s.detailsFailed),
    );
    final height = MediaQuery.sizeOf(context).height * 0.8;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          if (pages.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, MorrowSpacing.lg),
              child: Semantics(
                container: true,
                liveRegion: true,
                label: 'Page ${_index + 1} of ${pages.length}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    for (var i = 0; i < pages.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _index ? colors.primary : colors.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (failed)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, MorrowSpacing.md),
              child: ErrorBanner(
                title: 'Couldn’t save that choice',
                message: 'Nothing changed. Try again.',
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pager,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                for (final p in pages)
                  switch (p) {
                    DetailPage.context => _ContextPage(target: widget.target),
                    DetailPage.stoolForm => _StoolFormPage(
                      target: widget.target,
                    ),
                  },
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, MorrowSpacing.md, 24, 24),
            child: MorrowButton(
              label: _last ? 'Done' : 'Next',
              onPressed: _next,
            ),
          ),
        ],
      ),
    );
  }
}

/// Title with Clear, and a one-line subtitle, at the top of each page.
class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.onClear,
  });

  final String title;
  final String subtitle;

  /// Null when there is nothing to clear.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: text.titleLarge),
              ),
            ),
            // Shown only when there is something to clear; the space is kept
            // so the title does not move.
            Visibility(
              visible: onClear != null,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: TextButton(onPressed: onClear, child: const Text('Clear')),
            ),
          ],
        ),
        Text(subtitle, style: text.bodySmall!.copyWith(fontSize: 13)),
        const SizedBox(height: MorrowSpacing.lg),
      ],
    );
  }
}

/// "Context" (3.2): how it felt, and what was going on.
class _ContextPage extends ConsumerWidget {
  const _ContextPage({required this.target});

  final EntryTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(entryPageProvider(target).select((s) => s.details));
    final controller = ref.read(entryPageProvider(target).notifier);
    final text = Theme.of(context).textTheme;

    List<Widget> chips(List<Tag> tags) => [
      for (final t in tags)
        MorrowChip(
          label: tagLabel(t),
          selected: d.tags.contains(t),
          onSelected: (_) => controller.toggleTag(t),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        _PageHeader(
          title: 'Context',
          subtitle: 'Saved as you choose',
          onClear: d.contextEmpty ? null : controller.clearContext,
        ),
        Semantics(
          header: true,
          child: Text('How did it feel?', style: text.titleMedium),
        ),
        const SizedBox(height: MorrowSpacing.md),
        MorrowSegmented<Ease>(
          values: Ease.values,
          labelOf: easeChip,
          selected: d.ease,
          onTap: controller.toggleEase,
        ),
        const SizedBox(height: MorrowSpacing.xxl),
        // The hint sits beside the heading, or below it at large text.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: MorrowSpacing.md,
          runSpacing: MorrowSpacing.xs,
          children: [
            Semantics(
              header: true,
              child: Text('Anything going on?', style: text.titleMedium),
            ),
            Text('Choose all that apply', style: text.labelSmall),
          ],
        ),
        const SizedBox(height: MorrowSpacing.md),
        // Two short groups, close together: food and drink, then body and
        // mind. The chips' own tap areas keep a visible gap between rows.
        ChipWrap(runSpacing: 0, children: chips(_foodAndDrink)),
        const SizedBox(height: MorrowSpacing.xs),
        ChipWrap(runSpacing: 0, children: chips(_bodyAndMind)),
        const SizedBox(height: MorrowSpacing.lg),
      ],
    );
  }
}

/// "Stool form" (3.3).
class _StoolFormPage extends ConsumerWidget {
  const _StoolFormPage({required this.target});

  final EntryTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(
      entryPageProvider(target).select((s) => s.details.stoolType),
    );
    final controller = ref.read(entryPageProvider(target).notifier);
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        _PageHeader(
          title: 'Stool form',
          subtitle: 'Choose the closest match',
          onClear: type == null ? null : controller.clearStoolForm,
        ),
        for (final t in stoolForms.keys) ...[
          _StoolOption(
            type: t,
            selected: type == t,
            onTap: () => controller.toggleStoolType(t),
          ),
          const SizedBox(height: MorrowSpacing.sm),
        ],
        const SizedBox(height: MorrowSpacing.sm),
        Text(
          'Bristol Stool Form Scale · Types describe form, not a diagnosis.',
          style: text.labelSmall!.copyWith(color: colors.mutedText),
        ),
        const SizedBox(height: MorrowSpacing.lg),
      ],
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
