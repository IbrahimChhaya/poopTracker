import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';

/// A single-choice segmented control, as used for "How did it feel?".
///
/// Tapping the chosen segment again clears the choice. The chosen segment
/// shows a check mark and bolder text as well as colour, and screen readers
/// hear it as a selected item in a group ("1 of 3"). When a label would not
/// fit its segment on one line (large text), the segments stack as full-width
/// rows instead, so no word is ever broken.
class MorrowSegmented<T> extends StatelessWidget {
  const MorrowSegmented({
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T? selected;
  final ValueChanged<T>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final base = Theme.of(context).textTheme.bodySmall!;
    final radius = BorderRadius.circular(MorrowRadii.md);
    final tap = onTap;

    TextStyle styleFor(bool on) => on
        ? base.copyWith(color: colors.primary, fontWeight: FontWeight.w600)
        : base.copyWith(color: colors.ink);

    Widget segment(int i) {
      final v = values[i];
      final on = v == selected;
      final label = labelOf(v);
      return Semantics(
        button: true,
        selected: on,
        inMutuallyExclusiveGroup: true,
        label: '$label, ${i + 1} of ${values.length}',
        excludeSemantics: true,
        child: Material(
          color: on ? colors.tint : Colors.transparent,
          child: InkWell(
            onTap: tap == null ? null : () => tap(v),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: MorrowSizes.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MorrowSpacing.sm,
                  vertical: MorrowSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (on) ...[
                      Icon(Icons.check, size: 16, color: colors.primary),
                      const SizedBox(width: MorrowSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: styleFor(on),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    /// True when every label fits its segment on one line, with the check
    /// mark and padding.
    bool fitsInRow(double width) {
      final scaler = MediaQuery.textScalerOf(context);
      final segment = (width - (values.length - 1)) / values.length;
      const chrome = 2 * MorrowSpacing.sm + 16 + MorrowSpacing.xs;
      for (final v in values) {
        final painter = TextPainter(
          text: TextSpan(text: labelOf(v), style: styleFor(true)),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final w = painter.width;
        painter.dispose();
        if (w + chrome > segment) return false;
      }
      return true;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: radius,
        border: Border.all(color: colors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MorrowRadii.md - 1),
        child: LayoutBuilder(
          builder: (context, constraints) => fitsInRow(constraints.maxWidth)
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < values.length; i++) ...[
                        if (i > 0)
                          VerticalDivider(width: 1, color: colors.line),
                        Expanded(child: segment(i)),
                      ],
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < values.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: colors.line),
                      segment(i),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
