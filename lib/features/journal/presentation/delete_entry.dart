import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/scope.dart';
import '../../../core/diagnostics/diagnostic_log.dart';
import '../../../ui/widgets/overlays.dart';
import '../data/entry_repository.dart';

/// "Delete this entry?" (4.10). Deletes only after confirmation and reports
/// success only after the database commit. Returns true when deleted (or
/// when the entry was already gone).
Future<bool> confirmAndDeleteEntry(
  BuildContext context,
  WidgetRef ref,
  int entryId,
) async {
  final confirmed = await showMorrowConfirmDialog(
    context,
    title: 'Delete this entry?',
    message:
        'It will be removed from your journal on this phone. This can’t be '
        'undone.',
    confirmLabel: 'Delete entry',
    cancelLabel: 'Keep entry',
    destructive: true,
    dangerFilled: true,
  );
  if (!confirmed || !context.mounted) return false;

  try {
    await ref.read(entryRepositoryProvider).delete(entryId);
  } on EntryNotFoundException {
    // Already gone; nothing to undo.
  } on Object {
    ref.read(diagnosticLogProvider).record(DiagnosticEvent.entryDeleteFailed);
    if (context.mounted) {
      showMorrowToast(context, 'Couldn’t delete this entry. Nothing changed.');
    }
    return false;
  }
  if (context.mounted) showMorrowToast(context, 'Entry deleted');
  return true;
}
