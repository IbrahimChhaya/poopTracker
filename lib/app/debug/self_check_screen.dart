import 'package:flutter/material.dart';

import '../../core/diagnostics/encryption_self_check.dart';
import '../../ui/theme/morrow_colors.dart';
import '../../ui/theme/morrow_tokens.dart';
import '../../ui/widgets/morrow_button.dart';
import '../../ui/widgets/states.dart';

/// Developer screen that runs the on-device encryption self-check.
class SelfCheckScreen extends StatefulWidget {
  const SelfCheckScreen({super.key});

  @override
  State<SelfCheckScreen> createState() => _SelfCheckScreenState();
}

class _SelfCheckScreenState extends State<SelfCheckScreen> {
  List<SelfCheckStep>? _steps;
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    final steps = await runEncryptionSelfCheck();
    if (!mounted) return;
    setState(() {
      _steps = steps;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final steps = _steps;
    final allPassed = steps != null && steps.every((s) => s.passed);
    return Scaffold(
      appBar: AppBar(title: const Text('Encryption self-check')),
      body: ListView(
        padding: const EdgeInsets.all(MorrowSpacing.xxl),
        children: [
          const Text(
            'Creates a throwaway encrypted database with synthetic data, '
            'checks it, then deletes it. Your journal and its key are not '
            'touched.',
          ),
          const SizedBox(height: MorrowSpacing.lg),
          MorrowButton(
            label: 'Run self-check',
            busyLabel: 'Running…',
            busy: _running,
            onPressed: _run,
          ),
          const SizedBox(height: MorrowSpacing.xxl),
          if (_running) const LoadingState(label: 'Running self-check…'),
          if (steps != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                allPassed ? 'All checks passed' : 'Some checks failed',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  color: allPassed ? colors.primary : colors.danger,
                ),
              ),
            ),
            const SizedBox(height: MorrowSpacing.md),
            for (final s in steps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.passed ? Icons.check_circle_outline : Icons.error_outline,
                  color: s.passed ? colors.primary : colors.danger,
                ),
                title: Text('${s.passed ? 'Pass' : 'Fail'}: ${s.name}'),
                subtitle: s.detail == null || s.detail!.isEmpty
                    ? null
                    : Text(s.detail!),
              ),
          ],
        ],
      ),
    );
  }
}
