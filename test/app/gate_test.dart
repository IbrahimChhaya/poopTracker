import 'dart:collection';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/app/app.dart';
import 'package:poop_tracker/app/lock/lock_controller.dart';
import 'package:poop_tracker/app/providers.dart';
import 'package:poop_tracker/app/scope.dart';
import 'package:poop_tracker/core/database/app_database.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/database/journal_reset.dart';
import 'package:poop_tracker/ui/widgets/morrow_navigation_bar.dart';

import '../support/fake_key_store.dart';
import '../support/harness.dart';

/// A real (in-memory, unencrypted) database that records when it is closed.
/// Only for widget tests of the gate; encryption is tested in M3's tests.
class TrackingDatabase extends AppDatabase {
  TrackingDatabase() : super(NativeDatabase.memory());

  bool closed = false;

  @override
  Future<void> close() {
    closed = true;
    return super.close();
  }
}

/// Bootstrap that returns scripted results in order.
class ScriptedBootstrap extends DatabaseBootstrap {
  ScriptedBootstrap(List<Object> results)
    : _results = Queue.of(results),
      super(keyStore: FakeKeyStore(), databaseFile: _noFile);

  static Future<File> _noFile() async => File('unused');

  final Queue<Object> _results;
  int starts = 0;

  @override
  Future<StartupResult> start() async {
    starts++;
    final next = _results.length > 1 ? _results.removeFirst() : _results.first;
    if (next is StartupResult) return next;
    throw next as Error;
  }
}

class FakeReset extends JournalReset {
  FakeReset() : super(keyStore: FakeKeyStore(), databaseFile: _noFile);

  static Future<File> _noFile() async => File('unused');

  int erases = 0;
  bool fail = false;

  @override
  Future<void> eraseAll() async {
    erases++;
    if (fail) throw const FileSystemException('simulated');
  }
}

class TestLock extends LockController {
  @override
  AppLockState build() => AppLockState.unlocked;

  void set(AppLockState s) => state = s;
}

const _erase = 'Erase and start fresh…';

void main() {
  late ScriptedBootstrap bootstrap;
  late FakeReset reset;
  late TrackingDatabase db;
  late ProviderContainer container;

  Future<void> pumpApp(
    WidgetTester tester,
    List<Object> results, {
    double textScale = 1,
    Size size = figmaPhone,
  }) async {
    bootstrap = ScriptedBootstrap(results);
    reset = FakeReset();
    useScreenSize(tester, size);
    container = ProviderContainer(
      overrides: [
        databaseBootstrapProvider.overrideWithValue(bootstrap),
        journalResetProvider.overrideWithValue(reset),
        lockControllerProvider.overrideWith(TestLock.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const MorrowApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => db = TrackingDatabase());

  StartupReady ready() => StartupReady(db, createdNew: false);
  StartupBlocked blockedBy(StartupBlockReason r) => StartupBlocked(r);

  group('ready', () {
    testWidgets('opens the journal inside the shell', (tester) async {
      await pumpApp(tester, [ready()]);
      expect(find.byType(MorrowNavigationBar), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(bootstrap.starts, 1);
    });

    testWidgets('bottom navigation switches tabs', (tester) async {
      await pumpApp(tester, [ready()]);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Your history'), findsOneWidget);
      await tester.tap(find.text('Trends'));
      await tester.pumpAndSettle();
      expect(find.text('Your weeks'), findsOneWidget);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Encryption self-check'), findsOneWidget);
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('developer pages open from Settings in debug builds', (
      tester,
    ) async {
      await pumpApp(tester, [ready()]);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('UI kit preview'));
      await tester.pumpAndSettle();
      expect(find.text('UI kit'), findsOneWidget);
    });

    for (final scale in textScales) {
      testWidgets('every tab lays out at ${(scale * 100).toInt()}% text', (
        tester,
      ) async {
        await pumpApp(tester, [ready()], textScale: scale, size: smallPhone);
        for (final tab in ['History', 'Trends', 'Settings', 'Journal']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: tab);
        }
      });
    }
  });

  group('blocked', () {
    const eraseReasons = {
      StartupBlockReason.keyMissing,
      StartupBlockReason.keyRejected,
      StartupBlockReason.notEncrypted,
      StartupBlockReason.databaseUnreadable,
      StartupBlockReason.eraseFailed,
    };

    for (final reason in StartupBlockReason.values) {
      testWidgets('$reason: no journal, no automatic retry or creation', (
        tester,
      ) async {
        await pumpApp(tester, [blockedBy(reason)]);
        expect(find.text('Your journal can’t be opened right now'), findsOne);
        expect(find.byType(MorrowNavigationBar), findsNothing);
        expect(find.text('Try again'), findsOneWidget);
        expect(
          find.text(_erase),
          eraseReasons.contains(reason) ? findsOneWidget : findsNothing,
        );
        // Nothing happens on its own, however long we wait.
        await tester.pump(const Duration(minutes: 5));
        expect(bootstrap.starts, 1);
        expect(reset.erases, 0);
      });
    }

    testWidgets('an unexpected error is blocked, with retry only', (
      tester,
    ) async {
      await pumpApp(tester, [StateError('unexpected')]);
      expect(find.text('Your journal can’t be opened right now'), findsOne);
      expect(find.text(_erase), findsNothing);
      await tester.pump(const Duration(minutes: 5));
      expect(bootstrap.starts, 1, reason: 'no automatic retry');
    });

    testWidgets('Try again runs startup again', (tester) async {
      await pumpApp(tester, [
        blockedBy(StartupBlockReason.storageUnavailable),
        ready(),
      ]);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(bootstrap.starts, 2);
      expect(find.byType(MorrowNavigationBar), findsOneWidget);
    });
  });

  group('erase and start fresh', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text(_erase));
      await tester.pumpAndSettle();
      expect(find.text('Erase and start fresh?'), findsOneWidget);
    }

    FilledButton eraseButton(WidgetTester tester) => tester.widget(
      find.ancestor(
        of: find.text('Erase everything'),
        matching: find.byType(FilledButton),
      ),
    );

    testWidgets('needs the acknowledgement before erasing', (tester) async {
      await pumpApp(tester, [
        blockedBy(StartupBlockReason.keyMissing),
        ready(),
      ]);
      await openDialog(tester);
      expect(eraseButton(tester).onPressed, isNull);
      await tester.tap(find.text('Erase everything'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(reset.erases, 0);

      await tester.tap(find.text('I understand this can’t be undone'));
      await tester.pumpAndSettle();
      expect(eraseButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Erase everything'));
      await tester.pumpAndSettle();
      expect(reset.erases, 1);
      expect(bootstrap.starts, 2);
      expect(find.byType(MorrowNavigationBar), findsOneWidget);
    });

    testWidgets('Cancel erases nothing', (tester) async {
      await pumpApp(tester, [blockedBy(StartupBlockReason.keyRejected)]);
      await openDialog(tester);
      await tester.tap(find.text('I understand this can’t be undone'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(reset.erases, 0);
      expect(bootstrap.starts, 1);
      expect(find.text(_erase), findsOneWidget);
    });

    testWidgets('a failed erase stays blocked and can be retried', (
      tester,
    ) async {
      await pumpApp(tester, [blockedBy(StartupBlockReason.keyMissing)]);
      reset.fail = true;
      await openDialog(tester);
      await tester.tap(find.text('I understand this can’t be undone'));
      await tester.pump();
      await tester.tap(find.text('Erase everything'));
      await tester.pumpAndSettle();
      expect(reset.erases, 1);
      expect(bootstrap.starts, 1);
      expect(find.textContaining('couldn’t finish erasing'), findsOneWidget);
      expect(find.text(_erase), findsOneWidget);
    });
  });

  group('lock', () {
    testWidgets('locking removes the journal and closes the database', (
      tester,
    ) async {
      await pumpApp(tester, [ready()]);
      expect(find.text('Nothing here yet'), findsOneWidget);

      (container.read(lockControllerProvider.notifier) as TestLock).set(
        AppLockState.locked,
      );
      await tester.pumpAndSettle();
      expect(find.text('morrow is locked'), findsOneWidget);
      expect(find.byType(MorrowNavigationBar), findsNothing);
      expect(find.text('Nothing here yet'), findsNothing);
      expect(db.closed, isTrue);
    });

    for (final state in [
      AppLockState.uninitialised,
      AppLockState.locked,
      AppLockState.authenticating,
      AppLockState.error,
    ]) {
      testWidgets('$state never opens the journal', (tester) async {
        bootstrap = ScriptedBootstrap([ready()]);
        useScreenSize(tester, figmaPhone);
        container = ProviderContainer(
          overrides: [
            databaseBootstrapProvider.overrideWithValue(bootstrap),
            lockControllerProvider.overrideWith(() => _FixedLock(state)),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MorrowApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(bootstrap.starts, 0);
        expect(find.byType(MorrowNavigationBar), findsNothing);
      });
    }
  });

  group('unlocked scope', () {
    // Riverpod wraps a provider's error, once per provider in the chain.
    Matcher outsideScope() => throwsA(
      predicate((Object? e) {
        while (e is ProviderException) {
          e = e.exception;
        }
        return e is OutsideUnlockedScopeError;
      }),
    );

    test('sensitive providers cannot be read from the root', () {
      final root = ProviderContainer();
      addTearDown(root.dispose);
      expect(() => root.read(appDatabaseProvider), outsideScope());
      expect(() => root.read(entryRepositoryProvider), outsideScope());
    });

    testWidgets('a widget outside the scope cannot read journal data', (
      tester,
    ) async {
      Object? outsideError;
      Object? insideValue;
      await tester.pumpWidget(
        ProviderScope(
          child: Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  try {
                    ref.read(entryRepositoryProvider);
                  } on Object catch (e) {
                    outsideError = e;
                  }
                  return const SizedBox();
                },
              ),
              UnlockedScope(
                database: db,
                child: Consumer(
                  builder: (context, ref, _) {
                    insideValue = ref.read(entryRepositoryProvider);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(outsideError, isNotNull);
      expect(insideValue, isNotNull);
      await db.close();
    });
  });
}

class _FixedLock extends LockController {
  _FixedLock(this._state);

  final AppLockState _state;

  @override
  AppLockState build() => _state;
}
