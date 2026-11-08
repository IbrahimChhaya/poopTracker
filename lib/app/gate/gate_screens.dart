import 'package:flutter/material.dart';

import '../../core/database/bootstrap.dart';
import '../../ui/theme/morrow_colors.dart';
import '../../ui/theme/morrow_tokens.dart';
import '../../ui/theme/morrow_typography.dart';
import '../../ui/widgets/morrow_button.dart';
import '../../ui/widgets/states.dart';
import '../lock/lock_controller.dart';
import '../session/data_reset.dart';

/// The wordmark and a full-screen layout shared by the gate screens. These
/// screens never show journal content.
class _GateLayout extends StatelessWidget {
  const _GateLayout({required this.children, this.actions = const []});

  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.spa_outlined,
                          color: colors.primary,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'morrow',
                          style: MorrowTextStyles.of(context).wordmark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  ...children,
                ],
              ),
            ),
            if (actions.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.line)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: MorrowSpacing.md),
                        actions[i],
                      ],
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

/// Shown while the journal is being opened, created or erased.
class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({this.label = 'Opening your journal…', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _GateLayout(children: [LoadingState(label: label)]);
  }
}

/// "morrow is locked" (7.4) and "Couldn’t unlock" (7.5). Contains no
/// journal content.
class LockedScreen extends StatelessWidget {
  const LockedScreen({
    required this.state,
    required this.problem,
    required this.onUnlock,
    super.key,
  });

  final AppLockState state;
  final LockProblem? problem;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final busy =
        state == AppLockState.authenticating ||
        state == AppLockState.uninitialised;
    final (String title, String message)? banner = switch (problem) {
      null => null,
      LockProblem.didNotUnlock => (
        'Couldn’t unlock',
        'Authentication was cancelled or didn’t match. Try again, or wait '
            'a moment if you’ve tried several times.',
      ),
      LockProblem.lockedOut => (
        'Too many tries',
        'Unlocking is paused for a while. Wait a moment, then try again.',
      ),
      LockProblem.notAvailable => (
        'Set up a screen lock',
        'morrow unlocks with your phone’s fingerprint, face or passcode. '
            'Set a screen lock in your phone’s settings, then try again.',
      ),
      LockProblem.promptFailed => (
        'Couldn’t show the unlock prompt',
        'Nothing has changed. Try again.',
      ),
      LockProblem.settingUnreadable => (
        'Couldn’t check app lock',
        'This phone’s secure storage didn’t respond. Nothing has '
            'changed. Try again in a moment.',
      ),
    };
    return _GateLayout(
      actions: [
        MorrowButton(
          label: banner == null ? 'Unlock' : 'Try again',
          busy: busy,
          busyLabel: 'Unlocking…',
          onPressed: onUnlock,
        ),
      ],
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.tint,
              shape: BoxShape.circle,
            ),
            child: ExcludeSemantics(
              child: Icon(Icons.lock_outline, color: colors.primary),
            ),
          ),
        ),
        const SizedBox(height: MorrowSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            'morrow is locked',
            textAlign: TextAlign.center,
            style: text.headlineSmall,
          ),
        ),
        const SizedBox(height: MorrowSpacing.sm),
        Text(
          banner == null
              ? 'Unlock with your fingerprint, face or phone passcode.'
              : 'Your journal stays locked until you unlock it.',
          textAlign: TextAlign.center,
          style: text.bodyMedium!.copyWith(color: colors.mutedText),
        ),
        if (banner != null) ...[
          const SizedBox(height: MorrowSpacing.xl),
          ErrorBanner(title: banner.$1, message: banner.$2),
        ],
      ],
    );
  }
}

/// "Deleting your data…" (8.6), "All data deleted" (8.7) and the
/// failure screen. No journal exists at this point.
class DataResetScreen extends StatelessWidget {
  const DataResetScreen({
    required this.phase,
    required this.onStartAgain,
    required this.onRetry,
    super.key,
  });

  final ResetPhase phase;
  final VoidCallback onStartAgain;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;

    Widget centred(Widget icon, String title, String message) => Column(
      children: [
        const SizedBox(height: 80),
        Center(child: icon),
        const SizedBox(height: MorrowSpacing.lg),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: text.headlineSmall,
          ),
        ),
        const SizedBox(height: MorrowSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: text.bodyMedium!.copyWith(color: colors.mutedText),
        ),
      ],
    );

    Widget badge(IconData icon, Color background, Color foreground) =>
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: ExcludeSemantics(child: Icon(icon, color: foreground)),
        );

    return switch (phase) {
      ResetPhase.deleted => _GateLayout(
        actions: [MorrowButton(label: 'Start again', onPressed: onStartAgain)],
        children: [
          centred(
            badge(Icons.check, colors.tint, colors.primary),
            'All data deleted',
            'Your entries, settings and reminder have been removed from this '
                'phone.',
          ),
        ],
      ),
      ResetPhase.failed => _GateLayout(
        actions: [MorrowButton(label: 'Try again', onPressed: onRetry)],
        children: [
          centred(
            badge(Icons.error_outline, colors.sand, colors.danger),
            'Couldn’t finish deleting',
            'Some data may still be on this phone. Nothing will be opened '
                'until deleting finishes. Try again.',
          ),
        ],
      ),
      _ => _GateLayout(
        children: [
          centred(
            const SizedBox.square(
              dimension: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            'Deleting your data…',
            'Please keep morrow open until this finishes.',
          ),
        ],
      ),
    };
  }
}

/// What the blocked screen says and offers for each reason.
class BlockedCopy {
  const BlockedCopy({
    required this.message,
    this.offerErase = false,
    this.offerRetry = true,
  });

  final String message;

  /// Erasing helps only when a journal exists that cannot be opened. It is
  /// never offered for temporary problems.
  final bool offerErase;
  final bool offerRetry;

  static BlockedCopy forReason(StartupBlockReason? reason) => switch (reason) {
    StartupBlockReason.keyMissing ||
    StartupBlockReason.keyRejected => const BlockedCopy(
      message:
          'morrow couldn’t access the key that protects your entries on '
          'this phone. Nothing has been changed or deleted.',
      offerErase: true,
    ),
    StartupBlockReason.notEncrypted ||
    StartupBlockReason.databaseUnreadable => const BlockedCopy(
      message:
          'morrow found journal data on this phone that it can’t read '
          'safely. Nothing has been changed or deleted.',
      offerErase: true,
    ),
    StartupBlockReason.storageUnavailable => const BlockedCopy(
      message:
          'morrow couldn’t read this phone’s secure storage. Nothing has '
          'been changed or deleted. Try again in a moment, or restart your '
          'phone.',
    ),
    StartupBlockReason.encryptionUnavailable => const BlockedCopy(
      message:
          'This copy of morrow can’t protect your journal, so it won’t open '
          'it. Nothing has been changed or deleted. Try updating or '
          'reinstalling morrow.',
    ),
    StartupBlockReason.setupFailed => const BlockedCopy(
      message: 'morrow couldn’t finish setting up. Please try again.',
    ),
    StartupBlockReason.eraseFailed => const BlockedCopy(
      message:
          'morrow couldn’t finish erasing its data on this phone. You can '
          'try erasing again.',
      offerErase: true,
    ),
    null => const BlockedCopy(
      message:
          'Something went wrong while opening your journal. Nothing has been '
          'changed or deleted.',
    ),
  };
}

/// "Your journal can't be opened right now" (screen 8.8).
///
/// Never creates a journal by itself. Erasing is a separate, confirmed step.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({
    required this.reason,
    required this.onRetry,
    required this.onErase,
    super.key,
  });

  /// Null for an unexpected error.
  final StartupBlockReason? reason;
  final VoidCallback onRetry;
  final VoidCallback onErase;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final copy = BlockedCopy.forReason(reason);

    return _GateLayout(
      actions: [
        if (copy.offerRetry)
          MorrowButton(label: 'Try again', onPressed: onRetry),
        if (copy.offerErase)
          MorrowButton(
            label: 'Erase and start fresh…',
            variant: MorrowButtonVariant.dangerOutline,
            onPressed: onErase,
          ),
      ],
      children: [
        ExcludeSemantics(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.sand,
                borderRadius: BorderRadius.circular(MorrowRadii.lg),
              ),
              child: Icon(Icons.error_outline, color: colors.danger),
            ),
          ),
        ),
        const SizedBox(height: MorrowSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            'Your journal can’t be opened right now',
            style: text.headlineSmall!.copyWith(fontSize: 24),
          ),
        ),
        const SizedBox(height: MorrowSpacing.md),
        Text(copy.message, style: text.bodyLarge),
        if (copy.offerErase) ...[
          const SizedBox(height: MorrowSpacing.xxl),
          Text('Still stuck?', style: text.titleSmall!.copyWith(fontSize: 14)),
          const SizedBox(height: MorrowSpacing.xs),
          Text(
            'If the key is gone, for example after restoring this phone from '
            'a backup, entries may not be recoverable. As a last resort you '
            'can erase morrow’s data on this phone and start fresh. If you '
            'have a backup, you can restore it afterwards.',
            style: text.bodySmall!.copyWith(fontSize: 13),
          ),
        ],
      ],
    );
  }
}

/// "Erase and start fresh?" (screen 8.9). Completes with true only if the
/// user ticks the acknowledgement and chooses "Erase everything".
Future<bool> confirmEraseAndStartFresh(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => const _EraseDialog(),
  );
  return result ?? false;
}

class _EraseDialog extends StatefulWidget {
  const _EraseDialog();

  @override
  State<_EraseDialog> createState() => _EraseDialogState();
}

class _EraseDialogState extends State<_EraseDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      title: const Text('Erase and start fresh?'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This permanently erases morrow’s data on this phone, including '
            'any entries that can’t be opened right now. It can’t be undone.',
          ),
          const SizedBox(height: MorrowSpacing.md),
          CheckboxListTile(
            value: _understood,
            onChanged: (v) => setState(() => _understood = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'I understand this can’t be undone',
              style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: MorrowSpacing.md),
          MorrowButton(
            label: 'Erase everything',
            variant: MorrowButtonVariant.danger,
            onPressed: _understood
                ? () => Navigator.of(context).pop(true)
                : null,
          ),
          const SizedBox(height: 10),
          MorrowButton(
            label: 'Cancel',
            variant: MorrowButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
