import 'package:flutter/material.dart';

import '../../../../ui/theme/morrow_colors.dart';
import '../../../../ui/theme/morrow_tokens.dart';
import '../../domain/entry.dart';

/// One entry in a list: a title (for example "Today · 1:35 pm") and the note,
/// or "No note". Optional details are not shown here until M6.
class EntryCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final note = entry.comment;
    final radius = BorderRadius.circular(MorrowRadii.xl);
    return Semantics(
      button: true,
      label: '$title. ${note ?? 'No note'}',
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        note ?? 'No note',
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
