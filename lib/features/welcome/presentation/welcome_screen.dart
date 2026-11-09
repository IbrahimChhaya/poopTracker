import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/paths.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/theme/morrow_typography.dart';
import '../../../ui/widgets/morrow_button.dart';
import '../../settings/presentation/settings_screen.dart';
import 'onboarding_layout.dart';
import 'previews.dart';
import 'welcome_controller.dart';

/// "Your quiet journal." (1.1): shown once on a new journal. Get started
/// opens the four-page tour; Restore from a backup opens 9.5 and, once a
/// backup is restored, the journal.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = MorrowColors.of(context);
    return OnboardingLayout(
      top: Padding(
        padding: const EdgeInsets.only(top: MorrowSpacing.sm),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.spa_outlined, color: colors.primary, size: 23),
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
      ),
      stage: const WelcomePreview(),
      title: 'Your quiet journal.',
      body:
          'Log an entry in one tap and look back week by week. Encrypted on '
          'this phone, with no account.',
      actions: [
        MorrowButton(
          label: 'Get started',
          onPressed: () =>
              context.push(AppPaths.tour, extra: TourMode.firstRun),
        ),
        TextButton(
          onPressed: () => context.push(
            SettingsScreen.restorePath,
            extra: RestoreOrigin.welcome,
          ),
          child: const Text('Restore from a backup'),
        ),
      ],
    );
  }
}

/// Where the restore flow was opened from: from the welcome, finishing a
/// restore goes on to the journal.
enum RestoreOrigin { welcome }
