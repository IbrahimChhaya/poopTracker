import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';

/// A single-choice segmented control, as used for "How did it feel?".
///
/// Tapping the chosen segment again clears the choice. The chosen segment
/// shows a check mark and bolder text as well as colour, and screen readers
/// hear it as a selected item in a group ("1 of 3"). The segments always sit
/// in one row: labels wrap between words, and a word too wide for its
/// segment at very large text shrinks just enough to fit, so no word is ever
/// broken.
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

    /// The text scaler for [label] in a segment [width] wide: the system
    /// size, or smaller if the label's longest word would not fit.
    TextScaler fitted(String label, TextStyle style, double width) {
      final scaler = MediaQuery.textScalerOf(context);
      var widest = 0.0;
      for (final word in label.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (painter.width > widest) widest = painter.width;
        painter.dispose();
      }
      if (widest == 0 || widest <= width) return scaler;
      return TextScaler.linear(scaler.scale(1) * width / widest);
    }

    Widget segment(int i, double segmentWidth) {
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
                        textScaler: fitted(
                          label,
                          styleFor(on),
                          segmentWidth -
                              2 * MorrowSpacing.sm -
                              (on ? 16 + MorrowSpacing.xs : 0),
                        ),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: radius,
        border: Border.all(color: colors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MorrowRadii.md - 1),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth =
                (constraints.maxWidth - (values.length - 1)) / values.length;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < values.length; i++) ...[
                    if (i > 0) VerticalDivider(width: 1, color: colors.line),
                    Expanded(child: segment(i, segmentWidth)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
