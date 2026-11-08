import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/scope.dart';
import '../../../../ui/theme/morrow_colors.dart';
import '../../../../ui/theme/morrow_tokens.dart';
import '../../domain/entry.dart';
import '../detail_labels.dart';
import 'stool_form_icon.dart';

/// One entry in a list: a title (for example "Today · 1:35 pm") and a
/// summary: "form · ease" when those details are shown (3.4, 4.3), otherwise
/// the note, or "No note".
class EntryCard extends ConsumerWidget {
  const EntryCard({
    required this.entry,
    required this.title,
    required this.onTap,
    super.key,
  });

  final Entry entry;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayProvider);
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(MorrowRadii.xl);

    final type = display.showStoolForm ? entry.stoolType : null;
    final ease = display.showContext ? entry.ease : null;

    final detailLine = [
      if (type != null) stoolForms[type]!.name,
      if (ease != null) easePhrase(ease),
    ].join(' · ');
    final summary = detailLine.isNotEmpty
        ? detailLine
        : entry.comment ?? 'No note';

    return Semantics(
      button: true,
      label: [title, if (type != null) 'Type $type', summary].join('. '),
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
            padding: const EdgeInsets.all(MorrowSpacing.lg),
            child: Row(
              children: [
                if (type != null) ...[
                  StoolFormTile(type: type),
                  const SizedBox(width: MorrowSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MorrowSpacing.md),
                Icon(Icons.chevron_right, size: 20, color: colors.mutedIcon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A heading with a count on the right, for example "This week's journal ·
/// 5 entries".
class SectionHeading extends StatelessWidget {
  const SectionHeading({required this.title, this.trailing, super.key});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: text.titleMedium),
          ),
        ),
        if (t != null) ...[
          const SizedBox(width: MorrowSpacing.md),
          Text(t, style: text.bodySmall),
        ],
      ],
    );
  }
}
