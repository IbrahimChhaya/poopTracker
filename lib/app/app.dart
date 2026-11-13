import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/bootstrap.dart';
import '../features/reminders/presentation/reminder_controller.dart';
import '../features/welcome/presentation/welcome_controller.dart';
import '../ui/format/labels.dart';
import '../ui/theme/morrow_colors.dart';
import '../ui/theme/morrow_theme.dart';
import '../ui/widgets/sprout_mark.dart';
import 'gate/gate_screens.dart';
import 'lock/lock_controller.dart';
import 'paths.dart';
import 'providers.dart';
import 'router.dart';
import 'scope.dart';
import 'session/data_reset.dart';
import 'session/journal_session.dart';

/// Root widget: the central gate.
///
/// 1. Lock gate: nothing sensitive exists until the session is unlocked.
/// 2. Journal gate: the encrypted journal is opened (or created) only in an
///    unlocked session. If it cannot be opened safely, the blocked screen is
///    shown and nothing is created or replaced.
/// 3. Unlocked scope: the database, data providers and router exist only
///    here, and are disposed together when the session ends.
class MorrowApp extends ConsumerStatefulWidget {
  const MorrowApp({super.key});

  @override
  ConsumerState<MorrowApp> createState() => _MorrowAppState();
}

class _MorrowAppState extends ConsumerState<MorrowApp> {
  late final AppLifecycleListener _lifecycle;

  /// True while app lock is on and the app is not in the foreground: a
  /// plain cover hides the screen before the phone takes its app-switcher
  /// snapshot.
  bool _covered = false;

  LockController get _lock => ref.read(lockControllerProvider.notifier);

  void _onLifecycle(AppLifecycleState s) {
    _lock.onLifecycle(s);
    final cover = _lock.enabled && s != AppLifecycleState.resumed;
    if (cover != _covered) setState(() => _covered = cover);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockControllerProvider);
    final reset = ref.watch(dataResetProvider);
    final resetter = ref.read(dataResetProvider.notifier);
    final Widget app = reset != ResetPhase.idle
        // "Delete all data" in progress or done: nothing else exists.
        ? _GateApp(
            home: DataResetScreen(
              phase: reset,
              onStartAgain: resetter.startAgain,
              onRetry: resetter.retry,
            ),
          )
        : lock == AppLockState.unlocked
        ? const _JournalGate()
        // Before the lock setting is read: no claim about a lock.
        : lock == AppLockState.uninitialised
        ? const _GateApp(home: StartingScreen())
        : _GateApp(
            home: LockedScreen(
              state: lock,
              problem: _lock.problem,
              onUnlock: _lock.unlock,
            ),
          );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [app, if (_covered) const _PrivacyCover()],
      ),
    );
  }
}

/// A plain cover with the morrow mark and nothing else.
class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover() : super(key: const ValueKey('privacy-cover'));

  @override
  Widget build(BuildContext context) {
    const colors = MorrowColors.light;
    return ColoredBox(
      color: colors.background,
      child: Center(child: SproutMark(color: colors.primary, size: 40)),
    );
  }
}

/// A plain app for gate screens, with no router and no journal access.
class _GateApp extends StatelessWidget {
  const _GateApp({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'morrow',
      debugShowCheckedModeBanner: false,
      theme: buildMorrowTheme(),
      home: home,
    );
  }
}

class _JournalGate extends ConsumerWidget {
  const _JournalGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(journalSessionProvider);
    final controller = ref.read(journalSessionProvider.notifier);

    Widget blocked(StartupBlockReason? reason) => _GateApp(
      home: Builder(
        builder: (context) => BlockedScreen(
          reason: reason,
          onRetry: controller.retry,
          onErase: () async {
            if (await confirmEraseAndStartFresh(context)) {
              await controller.eraseAndStartFresh();
            }
          },
        ),
      ),
    );

    final erase = ref.watch(erasePhaseProvider);
    return switch (session) {
      AsyncData(value: StartupReady()) when erase == ErasePhase.erased =>
        _GateApp(
          home: ErasedScreen(
            onContinue: () =>
                ref.read(erasePhaseProvider.notifier).set(ErasePhase.none),
          ),
        ),
      // An existing journal opens at once. If it is still empty and the
      // welcome was never finished (a first launch that was interrupted),
      // the welcome follows; a journal with entries never shows it.
      AsyncData(value: StartupReady(:final database, createdNew: false)) =>
        UnlockedScope(
          database: database,
          child: const _UnlockedApp(
            startAtWelcome: false,
            welcomeIfEmpty: true,
          ),
        ),
      AsyncData(value: StartupReady(:final database, :final createdNew)) =>
        switch (ref.watch(_welcomeDueProvider(createdNew))) {
          AsyncData(:final value) => UnlockedScope(
            database: database,
            child: _UnlockedApp(startAtWelcome: value),
          ),
          _ => const _GateApp(home: StartupLoadingScreen()),
        },
      AsyncData(value: StartupBlocked(:final reason)) => blocked(reason),
      AsyncError() => blocked(null),
      _ => _GateApp(
        home: erase == ErasePhase.erasing
            ? const StartupLoadingScreen(label: 'Erasing morrow’s data…')
            : const StartupLoadingScreen(),
      ),
    };
  }
}

/// The real app, inside the unlocked scope. Owns the router for this
/// session only.
/// Whether a newly created journal should open on the welcome (1.1).
final _welcomeDueProvider = FutureProvider.autoDispose.family<bool, bool>(
  (ref, createdNew) => welcomeDue(
    ref.read(welcomeStoreProvider).readSeen,
    createdNew: createdNew,
  ),
);

class _UnlockedApp extends ConsumerStatefulWidget {
  const _UnlockedApp({
    required this.startAtWelcome,
    this.welcomeIfEmpty = false,
  });

  final bool startAtWelcome;

  /// Check after opening whether an empty journal still owes the welcome.
  final bool welcomeIfEmpty;

  @override
  ConsumerState<_UnlockedApp> createState() => _UnlockedAppState();
}

class _UnlockedAppState extends ConsumerState<_UnlockedApp> {
  late final GoRouter _router = buildAppRouter(
    initialLocation: widget.startAtWelcome
        ? AppPaths.welcome
        : AppPaths.journal,
  );

  /// Makes the OS reminder match what the user asked for whenever the
  /// journal opens and whenever the app comes back (a time-zone change,
  /// permission revoked in Settings, or a Force Stop that cleared it).
  late final AppLifecycleListener _lifecycle;

  void _reconcileReminder() {
    final reminder = ref.read(reminderControllerProvider);
    if (reminder.hasValue) {
      ref.read(reminderControllerProvider.notifier).reconcile();
    }
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _reconcileReminder);
    if (widget.welcomeIfEmpty) unawaited(_welcomeIfStillDue());
    // Building the controller reconciles once.
    ref.read(reminderControllerProvider);
  }

  Future<void> _welcomeIfStillDue() async {
    final bool seen;
    try {
      seen = await ref.read(welcomeStoreProvider).readSeen();
    } on Object {
      return;
    }
    if (seen || !mounted) return;
    final entries = await ref.read(entryRepositoryProvider).all();
    if (entries.isEmpty && mounted) _router.go(AppPaths.welcome);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'morrow',
      debugShowCheckedModeBanner: false,
      theme: buildMorrowTheme(),
      routerConfig: _router,
      builder: (context, child) {
        // Every time label follows the phone's 12- or 24-hour setting.
        use24HourClock = MediaQuery.alwaysUse24HourFormatOf(context);
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
