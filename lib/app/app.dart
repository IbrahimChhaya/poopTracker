import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/bootstrap.dart';
import '../ui/theme/morrow_theme.dart';
import 'gate/gate_screens.dart';
import 'lock/lock_controller.dart';
import 'router.dart';
import 'scope.dart';
import 'session/journal_session.dart';

/// Root widget: the central gate.
///
/// 1. Lock gate: nothing sensitive exists until the session is unlocked.
/// 2. Journal gate: the encrypted journal is opened (or created) only in an
///    unlocked session. If it cannot be opened safely, the blocked screen is
///    shown and nothing is created or replaced.
/// 3. Unlocked scope: the database, data providers and router exist only
///    here, and are disposed together when the session ends.
class MorrowApp extends ConsumerWidget {
  const MorrowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(lockControllerProvider);
    if (lock != AppLockState.unlocked) {
      return const _GateApp(home: LockedScreen());
    }
    return const _JournalGate();
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
class _UnlockedApp extends StatefulWidget {
  const _UnlockedApp();

  @override
  State<_UnlockedApp> createState() => _UnlockedAppState();
}

class _UnlockedAppState extends State<_UnlockedApp> {
  late final GoRouter _router = buildAppRouter();

  @override
  void dispose() {
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
