import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lock/lock_controller.dart';
import '../../../app/scope.dart';
import '../../../app/session/data_reset.dart';
import '../../../core/security/device_auth.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/back_header.dart';
import '../../../ui/widgets/morrow_button.dart';
import '../../../ui/widgets/overlays.dart';

/// "Delete all data" (8.4). The button works only once the person ticks
/// "I understand"; with app lock on, the system prompt confirms it's them
/// (8.5). Deleting then replaces the whole app with 8.6 and 8.7.
class DeleteAllDataScreen extends ConsumerStatefulWidget {
  const DeleteAllDataScreen({super.key});

  @override
  ConsumerState<DeleteAllDataScreen> createState() =>
      _DeleteAllDataScreenState();
}

class _DeleteAllDataScreenState extends ConsumerState<DeleteAllDataScreen> {
  bool _understood = false;
  bool _busy = false;

  Future<void> _delete() async {
    if (_busy || !_understood) return;
    setState(() => _busy = true);
    final outcome = await ref
        .read(lockControllerProvider.notifier)
        .confirmDeletion();
    if (!mounted) return;
    if (outcome == AuthOutcome.success) {
      // Closes the journal and tears down this screen with the rest of
      // the unlocked app.
      await ref
          .read(dataResetProvider.notifier)
          .deleteEverything(ref.read(appDatabaseProvider));
      return;
    }
    setState(() => _busy = false);
    final message = switch (outcome) {
      AuthOutcome.lockedOut => 'Too many tries. Wait a moment, then try again.',
      AuthOutcome.notAvailable =>
        'Couldn’t confirm it’s you. Check your phone’s screen lock.',
      AuthOutcome.error => 'Couldn’t confirm it’s you. Nothing was deleted.',
      _ => null,
    };
    if (message != null) showMorrowToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  const BackHeader(title: 'Delete all data'),
                  const SizedBox(height: 64),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: colors.sand,
                        shape: BoxShape.circle,
                      ),
                      child: ExcludeSemantics(
                        child: Icon(
                          Icons.delete_outline,
                          size: 32,
                          color: colors.danger,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: MorrowSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      'Delete everything?',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: MorrowSpacing.sm),
                  Text(
                    'This permanently removes every entry, setting and '
                    'reminder from this phone. It can’t be undone. Export a '
                    'backup first if you want to keep a copy.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium!.copyWith(color: colors.mutedText),
                  ),
                  const SizedBox(height: MorrowSpacing.lg),
                  Material(
                    color: colors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MorrowRadii.lg),
                      side: BorderSide(color: colors.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CheckboxListTile(
                      value: _understood,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _understood = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MorrowRadii.lg),
                      ),
                      title: Text(
                        'I understand this can’t be undone',
                        style: text.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.line)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  children: [
                    MorrowButton(
                      label: 'Delete all data',
                      variant: MorrowButtonVariant.danger,
                      busy: _busy,
                      busyLabel: 'Deleting…',
                      onPressed: _understood ? _delete : null,
                    ),
                    const SizedBox(height: MorrowSpacing.md),
                    MorrowButton(
                      label: 'Cancel',
                      variant: MorrowButtonVariant.secondary,
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
