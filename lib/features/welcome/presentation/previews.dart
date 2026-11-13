import 'package:flutter/material.dart';

import '../../../ui/format/labels.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/sprout_mark.dart';

/// Decorative slices of the real screens for the welcome and tour pages.
/// They show, they don't invite taps: no chevrons, arrows or live buttons.
/// They are hidden from screen readers and keep their size at any text
/// scale (the page's own text grows instead), shrinking to fit the stage.

String _time(int h, int m) => formatTime(DateTime.utc(2026, 11, 6, h, m));

/// The sage stage a preview sits on.
class PreviewStage extends StatelessWidget {
  const PreviewStage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: Container(
          constraints: const BoxConstraints(minHeight: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: colors.tint,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 318,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Paper extends StatelessWidget {
  const _Paper({required this.child, this.color, this.padding});

  final Widget child;
  final Color? color;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color ?? colors.card,
        borderRadius: BorderRadius.circular(MorrowRadii.xl),
        border: color == null ? Border.all(color: colors.line) : null,
      ),
      child: child,
    );
  }
}

/// "Today · 8:10 am", with an optional second line.
class PreviewEntry extends StatelessWidget {
  const PreviewEntry({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sub = subtitle;
    return _Paper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// A Monday-to-Sunday strip with Friday chosen.
class PreviewWeek extends StatelessWidget {
  const PreviewWeek({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: [
        Text('This week', style: text.labelMedium!.copyWith(color: colors.ink)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MorrowRadii.md),
                    border: i == 4 ? Border.all(color: colors.primary) : null,
                  ),
                  child: Column(
                    children: [
                      Text(letters[i], style: text.labelSmall),
                      const SizedBox(height: 4),
                      Text(
                        '${i + 2}',
                        style: text.titleMedium!.copyWith(
                          color: i > 4 ? colors.mutedText : colors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i == 2 || i == 3 || i == 4
                              ? colors.ink
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// "4 entries · Logged this week | 8:10 am · Most recent entry".
class PreviewStats extends StatelessWidget {
  const PreviewStats({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    Widget figure(String value, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: text.titleLarge!.copyWith(color: colors.primary)),
          const SizedBox(height: 2),
          Text(label, style: text.labelSmall),
        ],
      ),
    );
    return _Paper(
      color: colors.background,
      child: Row(
        children: [
          figure('4 entries', 'Logged this week'),
          Container(width: 1, height: 32, color: colors.tintLine),
          const SizedBox(width: 16),
          figure(_time(8, 10), 'Most recent entry'),
        ],
      ),
    );
  }
}

/// The welcome's preview: the week, its figures and two entries.
class WelcomePreview extends StatelessWidget {
  const WelcomePreview({super.key});

  @override
  Widget build(BuildContext context) => PreviewStage(
    children: [
      const PreviewWeek(),
      const PreviewStats(),
      PreviewEntry(title: 'Today · ${_time(8, 10)}'),
      PreviewEntry(
        title: 'Wednesday · ${_time(18, 20)}',
        subtitle: 'Quiet evening',
      ),
    ],
  );
}

/// 1.2: "Add an entry", drawn as an outline, then what it does.
class OneTapPreview extends StatelessWidget {
  const OneTapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return PreviewStage(
      children: [
        Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MorrowRadii.lg),
            border: Border.all(color: colors.primary),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Add an entry',
                style: text.labelLarge!.copyWith(color: colors.primary),
              ),
            ],
          ),
        ),
        _Paper(
          color: colors.background,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(Icons.check, size: 18, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Added to today',
                  style: text.bodyMedium!.copyWith(color: colors.primary),
                ),
              ),
              Text(
                'Undo',
                style: text.labelLarge!.copyWith(color: colors.primary),
              ),
            ],
          ),
        ),
        PreviewEntry(title: 'Today · ${_time(8, 10)}'),
      ],
    );
  }
}

/// 1.3b: what an entry shows once details are on (only the type number and
/// ease; never a drawing or the type's description).
class DetailsOnPreview extends StatelessWidget {
  const DetailsOnPreview({
    required this.stoolForm,
    required this.context_,
    super.key,
  });

  final bool stoolForm;
  final bool context_;

  @override
  Widget build(BuildContext context) => PreviewStage(
    children: [
      PreviewEntry(
        title: 'Today · ${_time(8, 10)}',
        subtitle: [if (stoolForm) 'Type 4', if (context_) 'Easy'].join(' · '),
      ),
    ],
  );
}

/// 1.4: four weekly bars, the latest in progress, and the generic reminder.
class WeeklyPreview extends StatelessWidget {
  const WeeklyPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    const counts = [4, 4, 5, 5];
    const labels = ['12 Oct', '19 Oct', '26 Oct', '2 Nov'];
    return PreviewStage(
      children: [
        _Paper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Entries each week', style: text.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 72 * counts[i] / 6,
                          decoration: BoxDecoration(
                            color: i == 3 ? colors.primary : colors.chartBar,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: text.labelSmall,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        _Paper(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SproutMark(color: colors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'morrow · Sunday, ${_time(18, 0)}',
                      style: text.labelSmall,
                    ),
                    const SizedBox(height: 2),
                    Text('Weekly check-in', style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text('Ready to add an entry?', style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
