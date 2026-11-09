import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_file.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/card_group.dart';
import '../../../ui/widgets/morrow_button.dart';
import '../../../ui/widgets/page_layouts.dart';
import '../../../ui/widgets/states.dart';
import 'backup_controller.dart';
import 'passphrase_field.dart';

/// "Export a backup" (9.1), "Creating your backup…" (9.2) and "Backup
/// saved" (9.4). The phone's own save sheet is 9.3.
class ExportBackupScreen extends ConsumerStatefulWidget {
  const ExportBackupScreen({super.key});

  @override
  ConsumerState<ExportBackupScreen> createState() => _ExportBackupScreenState();
}

class _ExportBackupScreenState extends ConsumerState<ExportBackupScreen> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();
  bool _checked = false;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _passphraseError {
    if (!_checked) return null;
    if (_passphrase.text.characters.length < minPassphraseLength) {
      return 'Use at least $minPassphraseLength characters.';
    }
    return null;
  }

  String? get _confirmError {
    if (!_checked || _passphraseError != null) return null;
    if (_confirm.text != _passphrase.text) {
      return 'The passphrases don’t match.';
    }
    return null;
  }

  void _create() {
    setState(() => _checked = true);
    if (_passphraseError != null || _confirmError != null) return;
    FocusScope.of(context).unfocus();
    final passphrase = _passphrase.text;
    // Nothing about the passphrase stays on screen once it is used.
    _passphrase.clear();
    _confirm.clear();
    _checked = false;
    ref.read(exportControllerProvider.notifier).create(passphrase);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exportControllerProvider);
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;

    return switch (state) {
      ExportWorking(:final entryCount) => PopScope(
        canPop: false,
        child: StatusPage(
          badge: StatusBadge.busy,
          title: 'Creating your backup…',
          message: entryCount == 0
              ? 'Please keep morrow open.'
              : 'Protecting ${_entries(entryCount)} with your passphrase. '
                    'Please keep morrow open.',
        ),
      ),
      ExportSaved(:final fileName, :final entryCount) => StatusPage(
        badge: StatusBadge.done,
        title: 'Backup saved',
        message:
            '${fileName.replaceAll('.morrow', '')} contains '
            '${_entries(entryCount)}.',
        below: const NoticeCard(
          title: 'Keep your passphrase safe',
          message:
              'Without it, this backup can’t be opened and morrow can’t '
              'recover it.',
        ),
        actions: [
          MorrowButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      ExportReady(:final failed) => SubPage(
        title: 'Export a backup',
        actions: [MorrowButton(label: 'Create backup', onPressed: _create)],
        children: [
          Text(
            'Save a copy of your entries to a file. You choose where it '
            'goes, for example Files, Google Drive or iCloud Drive.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: MorrowSpacing.lg),
          if (failed) ...[
            const ErrorBanner(
              title: 'Couldn’t create the backup',
              message: 'Nothing was saved. Try again.',
            ),
            const SizedBox(height: MorrowSpacing.lg),
          ],
          const CardGroup(
            children: [
              InfoRow(
                icon: Icons.notes,
                title: 'Included',
                subtitle:
                    'Entries with date, time, note and any optional details',
              ),
              InfoRow(
                icon: Icons.shield_outlined,
                title: 'Not included',
                subtitle: 'Reminders, settings and app lock',
              ),
            ],
          ),
          const SizedBox(height: MorrowSpacing.xxl),
          // Said before the choice, while it can still change behaviour.
          Text(
            'Choose a passphrase you’ll remember. If you forget it, this '
            'backup can’t be opened, and morrow can’t recover it.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: MorrowSpacing.lg),
          PassphraseField(
            label: 'Protect it with a passphrase',
            helperText: 'At least $minPassphraseLength characters',
            controller: _passphrase,
            errorText: _passphraseError,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: MorrowSpacing.lg),
          PassphraseField(
            label: 'Confirm passphrase',
            controller: _confirm,
            errorText: _confirmError,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: MorrowSpacing.lg),
          Text(
            'Once saved, the file is outside morrow. Anyone with the file '
            'and the passphrase can read it.',
            style: text.bodySmall!.copyWith(color: colors.mutedText),
          ),
        ],
      ),
    };
  }
}

String _entries(int n) => n == 1 ? '1 entry' : '$n entries';
