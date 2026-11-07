import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';
import 'morrow_button.dart';

/// Shows a confirmation dialog and completes with `true` only when the user
/// chooses [confirmLabel]. Dismissing it completes with `false`.
///
/// For a [destructive] action the safe choice ([cancelLabel]) is the filled
/// primary button and comes first, as in "Discard this entry?".
Future<bool> showMorrowConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      void close(bool value) => Navigator.of(context).pop(value);
      final confirm = MorrowButton(
        label: confirmLabel,
        variant: destructive
            ? MorrowButtonVariant.dangerOutline
            : MorrowButtonVariant.primary,
        onPressed: () => close(true),
      );
      final cancel = MorrowButton(
        label: cancelLabel,
        variant: destructive
            ? MorrowButtonVariant.primary
            : MorrowButtonVariant.secondary,
        onPressed: () => close(false),
      );
      final buttons = destructive ? [cancel, confirm] : [confirm, cancel];
      return AlertDialog(
        scrollable: true,
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Text(title),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: MorrowSpacing.lg),
            buttons[0],
            const SizedBox(height: 10),
            buttons[1],
          ],
        ),
      );
    },
  );
  return result ?? false;
}

/// Shows a modal bottom sheet with a drag handle and a title.
Future<T?> showMorrowSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final insets = MediaQuery.viewInsetsOf(context);
      return Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: MorrowSpacing.lg),
              builder(context),
            ],
          ),
        ),
      );
    },
  );
}

/// Shows a short confirmation such as "Entry saved".
///
/// Call this only after the action has actually succeeded.
void showMorrowToast(BuildContext context, String message) {
  final colors = MorrowColors.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(Icons.check, size: 18, color: colors.card),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
