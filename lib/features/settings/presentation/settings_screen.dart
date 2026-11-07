import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/encryption_self_check.dart';
import '../../../ui/widgets/card_group.dart';
import '../../../ui/widgets/page_body.dart';
import '../../../ui/widgets/setting_row.dart';

/// Settings. Real settings arrive in M6, M8, M9 and M10; for now only the
/// developer tools are listed, and only in debug or diagnostics builds.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String uiKitPath = '/settings/ui-kit';
  static const String selfCheckPath = '/settings/self-check';

  @override
  Widget build(BuildContext context) {
    return PageBody(
      title: 'Settings',
      children: [
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
