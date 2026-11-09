import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lock/lock_controller.dart';
import '../../../app/providers.dart';
import '../../../core/clock.dart';
import '../../../core/diagnostics/diagnostic_log.dart';
import '../../../core/platform/file_export.dart';
import '../../../core/time/local_date.dart';
import '../../../ui/format/labels.dart';
import '../../../ui/theme/morrow_colors.dart';
import '../../../ui/theme/morrow_tokens.dart';
import '../../../ui/widgets/back_header.dart';
import '../../../ui/widgets/card_group.dart';
import '../../../ui/widgets/morrow_button.dart';
import '../../../ui/widgets/overlays.dart';
import '../../../ui/widgets/page_layouts.dart';
import '../../../ui/widgets/setting_row.dart';
import '../../../ui/widgets/states.dart';

typedef DiagnosticsView = ({bool enabled, List<DiagnosticRecord> events});

/// View model for Diagnostics (10.2–10.6). Holds no journal data.
class DiagnosticsController extends AsyncNotifier<DiagnosticsView> {
  DiagnosticLog get _log => ref.read(diagnosticLogProvider);

  @override
  Future<DiagnosticsView> build() async =>
      (enabled: await _log.isEnabled(), events: await _log.recent());

  Future<void> setEnabled(bool enabled) async {
    await _log.setEnabled(enabled);
    ref.invalidateSelf();
    await future;
  }

  String fileName() {
    final d = ref.read(clockProvider).today();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'morrow-diagnostics-${d.year}-${two(d.month)}-${two(d.day)}.txt';
  }

  Future<List<int>> _bytes() async => diagnosticBytes(await _log.exportText());

  /// Opens the save sheet. True when saved.
  Future<bool> save() async {
    final bytes = await _bytes();
    final saved = await ref
        .read(lockControllerProvider.notifier)
        .whileSystemSheet(
          () => ref
              .read(fileExportProvider)
              .save(fileName: fileName(), bytes: bytes, mimeType: 'text/plain'),
        );
    if (saved) _log.record(DiagnosticEvent.logSaved);
    return saved;
  }

  /// Opens the share sheet, for example to email the log.
  Future<ShareOutcome> share() async {
    final bytes = await _bytes();
    final outcome = await ref
        .read(lockControllerProvider.notifier)
        .whileSystemSheet(
          () => ref
              .read(fileExportProvider)
              .share(
                fileName: fileName(),
                bytes: bytes,
                mimeType: 'text/plain',
                subject: 'morrow diagnostics',
              ),
        );
    if (outcome == ShareOutcome.shared) _log.record(DiagnosticEvent.logShared);
    return outcome;
  }
}

final diagnosticsProvider =
    AsyncNotifierProvider.autoDispose<DiagnosticsController, DiagnosticsView>(
      DiagnosticsController.new,
    );

/// "Diagnostics" (10.2, 10.6): what is recorded, the on/off switch, recent
/// events, and Save a copy / Share by email.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  bool _busy = false;

  DiagnosticsController get _controller =>
      ref.read(diagnosticsProvider.notifier);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(int count) => _run(() async {
    final bool saved;
    try {
      saved = await _controller.save();
    } on Object {
      if (mounted) {
        showMorrowToast(context, 'Couldn’t save the log. Nothing changed.');
      }
      return;
    }
    if (!saved || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LogSavedScreen(fileName: _controller.fileName(), events: count),
      ),
    );
  });

  /// "Share the log?" (10.3), then the phone's share sheet (10.4).
  Future<void> _share() => _run(() async {
    final go = await showMorrowConfirmDialog(
      context,
      title: 'Share the log?',
      message:
          'It holds app events only, never your entries or notes. Once '
          'shared, it leaves this phone and morrow can’t take it back.',
      confirmLabel: 'Continue',
      cancelLabel: 'Cancel',
    );
    if (!go || !mounted) return;
    final ShareOutcome outcome;
    try {
      outcome = await _controller.share();
    } on Object {
      if (mounted) showMorrowToast(context, 'Couldn’t open the share sheet.');
      return;
    }
    if (outcome == ShareOutcome.shared && mounted) {
      showMorrowToast(context, 'Log shared');
    }
  });

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(diagnosticsProvider);
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final v = view.value;
    final hasEvents = v != null && v.enabled && v.events.isNotEmpty;
    // At large text sizes two pinned buttons would leave little room for
    // the page, so they scroll with it instead.
    final pinned = MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MorrowButton(
          label: 'Save a copy',
          onPressed: hasEvents && !_busy ? () => _save(v.events.length) : null,
        ),
        const SizedBox(height: MorrowSpacing.md),
        MorrowButton(
          label: 'Share by email',
          variant: MorrowButtonVariant.secondary,
          onPressed: hasEvents && !_busy ? _share : null,
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  const BackHeader(title: 'Diagnostics'),
                  const SizedBox(height: MorrowSpacing.xxl),
                  Text(
                    'A short record of what the app did, kept on this phone. '
                    'If something goes wrong, you can save it or send it to '
                    'help find the problem.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: MorrowSpacing.xxl),
                  const CardGroup(
                    children: [
                      InfoRow(
                        icon: Icons.notes,
                        title: 'Recorded',
                        subtitle:
                            'App events, such as starting up, opening the '
                            'journal and anything that failed, with when they '
                            'happened',
                      ),
                      InfoRow(
                        icon: Icons.shield_outlined,
                        title: 'Never recorded',
                        subtitle: 'Your entries, notes, details or keys',
                      ),
                    ],
                  ),
                  const SizedBox(height: MorrowSpacing.xxl),
                  CardGroup(
                    children: [
                      SettingRow.toggle(
                        icon: Icons.notes,
                        title: 'Keep a diagnostic log',
                        subtitle: 'Turning it off deletes the log',
                        value: v?.enabled ?? true,
                        onChanged: v == null || _busy
                            ? null
                            : (on) => _run(() => _controller.setEnabled(on)),
                      ),
                    ],
                  ),
                  const SizedBox(height: MorrowSpacing.xxl),
                  Semantics(
                    header: true,
                    child: Text('Recent events', style: text.labelMedium),
                  ),
                  const SizedBox(height: MorrowSpacing.sm),
                  switch (view) {
                    AsyncData(:final value) => _EventList(view: value),
                    AsyncError() => const ErrorBanner(
                      title: 'Couldn’t read the log',
                      message: 'Nothing has been changed.',
                    ),
                    _ => const LoadingState(label: 'Loading…'),
                  },
                  const SizedBox(height: MorrowSpacing.md),
                  Text(
                    'Kept for ${diagnosticRetention.inDays} days, up to '
                    '$diagnosticMaxEvents events.',
                    style: text.labelSmall,
                  ),
                  if (!pinned) ...[
                    const SizedBox(height: MorrowSpacing.xxl),
                    actions,
                  ],
                ],
              ),
            ),
            if (pinned)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.line)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Recent events, newest first (up to the 50 latest on screen; the saved
/// file has them all).
class _EventList extends ConsumerWidget {
  const _EventList({required this.view});

  final DiagnosticsView view;

  static const int _shown = 50;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(clockProvider).today();
    final events = view.events;

    if (!view.enabled || events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MorrowSpacing.lg),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(MorrowRadii.lg),
          border: Border.all(color: colors.line),
        ),
        child: Text(
          view.enabled
              ? 'No events recorded yet.'
              : 'No events recorded. Turn the log on to keep one.',
          style: text.bodyMedium!.copyWith(color: colors.mutedText),
        ),
      );
    }

    String when(DateTime t) {
      final day = LocalDate(t.year, t.month, t.day);
      final time = formatTime(t);
      return day == today ? time : '${relativeDay(day, today: today)}, $time';
    }

    // At large text the time sits above the event, so neither is squeezed.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    Widget row(DiagnosticRecord r) {
      final time = Text(when(r.localTime), style: text.labelSmall);
      final label = Text(
        r.event.label,
        style: text.bodyMedium!.copyWith(color: colors.ink),
      );
      return MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MorrowSpacing.lg,
            vertical: 10,
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    time,
                    const SizedBox(height: MorrowSpacing.xxs),
                    label,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: MediaQuery.textScalerOf(context).scale(96),
                      child: time,
                    ),
                    const SizedBox(width: MorrowSpacing.md),
                    Expanded(child: label),
                  ],
                ),
        ),
      );
    }

    return CardGroup(children: [for (final r in events.take(_shown)) row(r)]);
  }
}

/// "Log saved" (10.5).
class LogSavedScreen extends StatelessWidget {
  const LogSavedScreen({
    required this.fileName,
    required this.events,
    super.key,
  });

  final String fileName;
  final int events;

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
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.tint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, color: colors.primary),
                    ),
                  ),
                  const SizedBox(height: MorrowSpacing.lg),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      'Log saved',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: MorrowSpacing.sm),
                  Text(
                    '$fileName has ${events == 1 ? '1 event' : '$events events'}.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium!.copyWith(color: colors.mutedText),
                  ),
                  const SizedBox(height: MorrowSpacing.xxl),
                  const NoticeCard(
                    title: 'It’s no longer only on morrow',
                    message:
                        'The copy is wherever you saved it. Delete it there '
                        'when you no longer need it.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: MorrowButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
