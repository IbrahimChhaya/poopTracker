import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lock/lock_controller.dart';
import '../../../core/security/device_auth.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/back_header.dart';
import '../../../ui/widgets/card_group.dart';
import '../../../ui/widgets/overlays.dart';
import '../../../ui/widgets/setting_row.dart';

/// "App lock" (7.1–7.3, 7.6). Turning it on or off asks for the phone's
/// fingerprint, face or passcode first; the system prompt is the
/// confirmation (7.2, 7.6), so morrow draws no sheet of its own.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _busy = false;

  LockController get _lock => ref.read(lockControllerProvider.notifier);

  Future<void> _toggle(bool on) async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await _lock.setEnabled(on);
    if (!mounted) return;
    setState(() => _busy = false);
    final message = switch (outcome) {
      AuthOutcome.success => on ? 'App lock is on' : 'App lock is off',
      AuthOutcome.cancelled || AuthOutcome.failed => null,
      AuthOutcome.lockedOut => 'Too many tries. Wait a moment, then try again.',
      AuthOutcome.notAvailable =>
        'Set up a screen lock in your phone’s settings first.',
      AuthOutcome.error => 'Couldn’t change app lock. Nothing changed.',
    };
    if (message != null) showMorrowToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final on = ref.watch(appLockEnabledProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            const BackHeader(title: 'App lock'),
            const SizedBox(height: MorrowSpacing.xxl),
            CardGroup(
              children: [
                SettingRow.toggle(
                  icon: Icons.lock_outline,
                  title: 'Require unlock',
                  subtitle: on ? 'On' : 'Off',
                  value: on,
                  onChanged: _busy ? null : _toggle,
                ),
              ],
            ),
            const SizedBox(height: MorrowSpacing.lg),
            Text(
              'When on, morrow asks for your fingerprint, face or phone '
              'passcode each time you open it or return to it.',
              style: text.bodySmall,
            ),
            const SizedBox(height: MorrowSpacing.md),
            Text(
              'Anyone who can unlock this phone can also unlock morrow. Your '
              'journal is encrypted on this phone either way.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
