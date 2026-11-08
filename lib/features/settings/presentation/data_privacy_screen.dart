import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/lock/lock_controller.dart';
import '../../../app/scope.dart';
import '../../../core/time/local_date.dart';
import '../../../ui/format/labels.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/back_header.dart';
import '../../../ui/widgets/card_group.dart';
import '../../../ui/widgets/setting_row.dart';
import 'settings_screen.dart';

/// "Data & privacy" (8.3). Export and restore join this screen in M11;
/// until then nothing here mentions a backup.
class DataPrivacyScreen extends ConsumerWidget {
  const DataPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final lockOn = ref.watch(appLockEnabledProvider);
    final entries = ref.watch(entriesProvider).value;

    final count = entries?.length;
    final countLabel = count == null
        ? null
        : count == 1
        ? '1 entry'
        : '$count entries';
    // Entries are newest first, so the last one is the earliest.
    final started = entries == null || entries.isEmpty
        ? 'No entries yet'
        : 'Journal started ${_longDate(entries.last.localDate)}';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            const BackHeader(title: 'Data & privacy'),
            const SizedBox(height: MorrowSpacing.xxl),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.tint,
                borderRadius: BorderRadius.circular(MorrowRadii.lg),
                border: Border.all(color: colors.tintLine),
              ),
              child: Padding(
                padding: const EdgeInsets.all(MorrowSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(MorrowRadii.md),
                          ),
                          child: ExcludeSemantics(
                            child: Icon(
                              Icons.shield_outlined,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: MorrowSpacing.md),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'Private by design.',
                              style: text.titleLarge!.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MorrowSpacing.md),
                    Text(
                      'Your records stay on this phone. No account, no cloud '
                      'syncing, and no data sent to us.',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: MorrowSpacing.md),
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.wifi_off,
                            size: 16,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: MorrowSpacing.sm),
                        Expanded(
                          child: Text(
                            'Works entirely offline',
                            style: text.bodySmall!.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MorrowSpacing.xxl),
            CardGroup(
              label: 'Keep it personal',
              children: [
                SettingRow.navigation(
                  icon: Icons.lock_outline,
                  title: 'App lock',
                  subtitle: lockOn
                      ? 'On · fingerprint, face or phone passcode'
                      : 'Off · fingerprint, face or phone passcode',
                  onTap: () => context.push(SettingsScreen.appLockPath),
                ),
              ],
            ),
            const SizedBox(height: MorrowSpacing.xxl),
            Semantics(
              header: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text('Your local data', style: text.titleMedium),
                  ),
                  if (countLabel != null)
                    Text(
                      countLabel,
                      style: text.bodySmall!.copyWith(color: colors.mutedText),
                    ),
                ],
              ),
            ),
            const SizedBox(height: MorrowSpacing.xs),
            Text(
              started,
              style: text.bodySmall!.copyWith(color: colors.mutedText),
            ),
            const SizedBox(height: MorrowSpacing.md),
            CardGroup(
              children: [
                SettingRow.navigation(
                  icon: Icons.delete_outline,
                  title: 'Delete all data',
                  subtitle: 'Permanently erase this phone’s journal',
                  destructive: true,
                  onTap: () => context.push(SettingsScreen.deletePath),
                ),
              ],
            ),
            const SizedBox(height: MorrowSpacing.xxl),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.sand,
                borderRadius: BorderRadius.circular(MorrowRadii.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(MorrowSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: colors.warmIcon,
                      ),
                    ),
                    const SizedBox(width: MorrowSpacing.md),
                    Expanded(
                      child: Text(
                        'Deleting the app or losing this phone erases your '
                        'journal. There’s no account to recover it from.',
                        style: text.bodySmall!.copyWith(color: colors.warmText),
                      ),
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

/// "24 October 2026".
String _longDate(LocalDate d) => '${d.day} ${monthName(d.month)} ${d.year}';
