import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/scope.dart';
import '../../../core/diagnostics/encryption_self_check.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/card_group.dart';
import '../../../ui/widgets/page_body.dart';
import '../../../ui/widgets/setting_row.dart';

/// Settings (8.1, 8.2). Reminders, app lock and data rows arrive in M8–M10.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String uiKitPath = '/settings/ui-kit';
  static const String selfCheckPath = '/settings/self-check';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayProvider);
    final repo = ref.read(settingsRepositoryProvider);
    return PageBody(
      title: 'Settings',
      children: [
        // Turning a setting off hides its details everywhere but keeps any
        // values already saved.
        CardGroup(
          label: 'Journal',
          children: [
            SettingRow.toggle(
              icon: Icons.notes,
              title: 'Stool form',
              subtitle:
                  'Add stool form to entries, and show it in your journal '
                  'and trends.',
              value: display.showStoolForm,
              onChanged: repo.setShowStoolForm,
            ),
            SettingRow.toggle(
              icon: Icons.monitor_heart_outlined,
              title: 'Context',
              subtitle:
                  'Add how it felt and what was going on to entries, and '
                  'show them in your journal.',
              value: display.showContext,
              onChanged: repo.setShowContext,
            ),
          ],
        ),
        const SizedBox(height: MorrowSpacing.xxl),
        if (kDebugMode || diagnosticsEnabled)
          CardGroup(
            label: 'Developer',
            children: [
              if (kDebugMode)
                SettingRow.navigation(
                  icon: Icons.palette_outlined,
                  title: 'UI kit preview',
                  subtitle: 'Debug builds only',
                  onTap: () => context.go(uiKitPath),
                ),
              SettingRow.navigation(
                icon: Icons.verified_user_outlined,
                title: 'Encryption self-check',
                subtitle: 'Uses throwaway data only',
                onTap: () => context.go(selfCheckPath),
              ),
            ],
          ),
      ],
    );
  }
}
