import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';

enum MorrowButtonVariant {
  /// Filled green, the main action on a screen.
  primary,

  /// Green outline, the alternative action.
  secondary,

  /// Danger-coloured outline, for example "Discard" in a dialog.
  dangerOutline,

  /// Filled danger, only for the final confirmation of a destructive action.
  danger,
}

/// Full-width button following the morrow designs.
///
/// While [busy] is true the button is disabled, shows a spinner and
/// [busyLabel], which prevents double submission.
class MorrowButton extends StatelessWidget {
  const MorrowButton({
    required this.label,
    required this.onPressed,
    this.variant = MorrowButtonVariant.primary,
    this.icon,
    this.busy = false,
    this.busyLabel,
    this.large = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final MorrowButtonVariant variant;
  final IconData? icon;
  final bool busy;

  /// Shown instead of [label] while [busy], for example "Saving…".
  final String? busyLabel;

  /// The taller, rounder style used for "Add an entry" on the journal.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final callback = busy ? null : onPressed;
    final shown = busy ? (busyLabel ?? label) : label;

    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        if (busy || icon != null) const SizedBox(width: MorrowSpacing.sm),
        Flexible(child: Text(shown, textAlign: TextAlign.center)),
      ],
    );

    final ButtonStyle? sizeStyle = large
        ? const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(
              Size(64, MorrowSizes.largeButtonMinHeight),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(MorrowRadii.lg)),
              ),
            ),
          )
        : null;

    final Widget button = switch (variant) {
      MorrowButtonVariant.primary => FilledButton(
        onPressed: callback,
        style: sizeStyle,
        child: child,
      ),
      MorrowButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        style: sizeStyle,
        child: child,
      ),
      MorrowButtonVariant.dangerOutline => OutlinedButton(
        onPressed: callback,
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? colors.mutedText
                : colors.danger,
          ),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
              color: s.contains(WidgetState.disabled)
                  ? colors.line
                  : colors.danger,
            ),
          ),
          overlayColor: WidgetStatePropertyAll(
            colors.danger.withValues(alpha: 0.08),
          ),
        ).merge(sizeStyle),
        child: child,
      ),
      MorrowButtonVariant.danger => FilledButton(
        onPressed: callback,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? colors.disabledSurface
                : colors.danger,
          ),
        ).merge(sizeStyle),
        child: child,
      ),
    };

    return SizedBox(width: double.infinity, child: button);
  }
}
