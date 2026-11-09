import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/bootstrap.dart';
import '../features/reminders/presentation/reminder_controller.dart';
import '../ui/theme/morrow_colors.dart';
import '../ui/theme/morrow_theme.dart';
import 'gate/gate_screens.dart';
import 'lock/lock_controller.dart';
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
      child: Center(
        child: Icon(Icons.spa_outlined, color: colors.primary, size: 40),
      ),
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

    return switch (session) {
      AsyncData(value: StartupReady(:final database)) => UnlockedScope(
        database: database,
        child: const _UnlockedApp(),
      ),
      AsyncData(value: StartupBlocked(:final reason)) => blocked(reason),
      AsyncError() => blocked(null),
      _ => const _GateApp(home: StartupLoadingScreen()),
    };
  }
}

/// The real app, inside the unlocked scope. Owns the router for this
/// session only.
class _UnlockedApp extends ConsumerStatefulWidget {
  const _UnlockedApp();

  @override
  ConsumerState<_UnlockedApp> createState() => _UnlockedAppState();
}

class _UnlockedAppState extends ConsumerState<_UnlockedApp> {
  late final GoRouter _router = buildAppRouter();

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
    // Building the controller reconciles once.
    ref.read(reminderControllerProvider);
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
    );
  }
}
