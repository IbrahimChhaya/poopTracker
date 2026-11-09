import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_file.dart';
import '../../../core/time/local_date.dart';
import '../../../ui/format/labels.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/card_group.dart';
import '../../../ui/widgets/morrow_button.dart';
import '../../../ui/widgets/page_layouts.dart';
import '../../../ui/widgets/states.dart';
import 'backup_controller.dart';
import 'passphrase_field.dart';

/// "Restore from a backup" (9.5), the passphrase (9.7), "Restoring your
/// entries…" (9.8), "Restore complete" (9.9) and "Couldn't restore"
/// (9.10). The phone's own file picker is 9.6.
class RestoreBackupScreen extends ConsumerStatefulWidget {
  const RestoreBackupScreen({super.key});

  @override
  ConsumerState<RestoreBackupScreen> createState() =>
      _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends ConsumerState<RestoreBackupScreen> {
  final _passphrase = TextEditingController();
  bool _choosing = false;

  RestoreController get _controller =>
      ref.read(restoreControllerProvider.notifier);

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    if (_choosing) return;
    setState(() => _choosing = true);
    await _controller.choose();
    if (mounted) setState(() => _choosing = false);
  }

  void _restore() {
    if (_passphrase.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final passphrase = _passphrase.text;
    _passphrase.clear();
    _controller.restore(passphrase);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restoreControllerProvider);
    final text = Theme.of(context).textTheme;

    return switch (state) {
      RestoreWorking() => const PopScope(
        canPop: false,
        child: StatusPage(
          badge: StatusBadge.busy,
          title: 'Restoring your entries…',
          message: 'Please keep morrow open until this finishes.',
        ),
      ),
      RestoreDone(:final added, :final skipped) => StatusPage(
        badge: StatusBadge.done,
        title: 'Restore complete',
        message: restoreSummary(added: added, skipped: skipped),
        actions: [
          MorrowButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      RestorePassphrase(:final fileName, :final sizeBytes, :final error) =>
        SubPage(
          title: 'Restore from a backup',
          actions: [
            MorrowButton(
              label: error == null ? 'Restore' : 'Try again',
              onPressed: _restore,
            ),
          ],
          children: [
            _FileCard(
              name: fileName,
              sizeBytes: sizeBytes,
              onChange: _controller.chooseAnother,
            ),
            const SizedBox(height: MorrowSpacing.lg),
            if (error != null) ...[
              ErrorBanner(
                title: 'Couldn’t restore',
                message: switch (error) {
                  RestoreError.cannotOpen =>
                    'The passphrase didn’t match, or the file isn’t a '
                        'morrow backup. Nothing was changed.',
                  RestoreError.newerVersion =>
                    'This backup was made by a newer version of morrow. '
                        'Update morrow, then try again. Nothing was changed.',
                  RestoreError.failed =>
                    'Something went wrong while adding the entries. '
                        'Nothing was changed.',
                },
              ),
              const SizedBox(height: MorrowSpacing.lg),
            ],
            PassphraseField(
              label: 'Passphrase',
              controller: _passphrase,
              onSubmitted: (_) => _restore(),
            ),
          ],
        ),
      RestoreChoose(:final problem) => SubPage(
        title: 'Restore from a backup',
        actions: [
          MorrowButton(
            label: 'Choose backup file',
            busy: _choosing,
            onPressed: _choose,
          ),
        ],
        children: [
          Text(
            'Add entries from a backup file you saved earlier. Nothing in '
            'your journal is replaced or deleted.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: MorrowSpacing.lg),
          if (problem != null) ...[
            ErrorBanner(
              title: 'Couldn’t use that file',
              message: problem == BackupProblem.newerVersion
                  ? 'This backup was made by a newer version of morrow. '
                        'Update morrow, then try again.'
                  : 'It isn’t a morrow backup. Choose the file you saved '
                        'from Export a backup.',
            ),
            const SizedBox(height: MorrowSpacing.lg),
          ],
          const CardGroup(
            children: [
              InfoRow(
                icon: Icons.check,
                title: 'Entries already here are kept',
                subtitle: 'Duplicates are skipped',
              ),
              InfoRow(
                icon: Icons.lock_outline,
                title: 'You’ll need your passphrase',
                subtitle: 'The one you chose when you made the backup',
              ),
            ],
          ),
        ],
      ),
    };
  }
}

/// "12 entries added. 6 were already in your journal and were skipped."
String restoreSummary({required int added, required int skipped}) {
  final a = added == 1 ? '1 entry added.' : '$added entries added.';
  if (skipped == 0) return a;
  final s = skipped == 1
      ? '1 was already in your journal and was skipped.'
      : '$skipped were already in your journal and were skipped.';
  return '$a $s';
}

/// "4 KB", "1.2 MB".
String formatFileSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

final RegExp _datedName = RegExp(r'morrow-backup-(\d{4})-(\d{2})-(\d{2})');

/// The picked file, as in 9.7: its name, and the date it was made (from
/// the name) with its size.
class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.name,
    required this.sizeBytes,
    required this.onChange,
  });

  final String name;
  final int sizeBytes;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final m = _datedName.firstMatch(name);
    final made = m == null
        ? null
        : formatDayMonth(
            LocalDate(
              int.parse(m.group(1)!),
              int.parse(m.group(2)!),
              int.parse(m.group(3)!),
            ),
            withYear: true,
          );
    final details = [?made, formatFileSize(sizeBytes)].join(' · ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(MorrowRadii.lg),
        border: Border.all(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.description_outlined, color: colors.ink),
            ),
            const SizedBox(width: MorrowSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.endsWith('.morrow')
                        ? name.substring(0, name.length - 7)
                        : name,
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: MorrowSpacing.xxs),
                  Text(
                    details,
                    style: text.bodySmall!.copyWith(color: colors.mutedText),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onChange, child: const Text('Change')),
          ],
        ),
      ),
    );
  }
}
