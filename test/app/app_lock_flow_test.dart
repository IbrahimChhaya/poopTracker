import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/security/device_auth.dart';
import 'package:poop_tracker/features/journal/data/entry_repository.dart';
import 'package:poop_tracker/features/journal/domain/entry.dart';

import '../support/app_harness.dart';
import '../support/fake_clock.dart';
import '../support/fake_lock.dart';
import '../support/harness.dart';

final Finder _cover = find.byKey(const ValueKey('privacy-cover'));

void main() {
  late TrackingDatabase db;
  late FakeAuthenticator auth;
  late FakeLockSettings settings;

  setUp(() async {
    db = TrackingDatabase();
    auth = FakeAuthenticator(hold: true);
    settings = FakeLockSettings(enabled: true);
    await EntryRepository(db, figmaNow).create(
      EntryDraft(
        occurredAtUtc: DateTime.utc(2026, 11, 6, 13, 35),
        originalUtcOffsetMinutes: 0,
        comment: 'Synthetic private note',
      ),
    );
  });

  Future<void> pump(WidgetTester tester, {double textScale = 1}) =>
      pumpMorrowApp(
        tester,
        [StartupReady(db, createdNew: false)],
        authenticator: auth,
        lockSettings: settings,
        textScale: textScale,
        size: textScale > 1 ? smallPhone : figmaPhone,
      ).then((_) {});

  Future<void> answer(WidgetTester tester, AuthOutcome outcome) async {
    auth.complete(outcome);
    await tester.pumpAndSettle();
  }

  void expectNothingSensitive() {
    expect(find.text('Your journal'), findsNothing);
    expect(find.text('Synthetic private note'), findsNothing);
    expect(find.textContaining('1:35'), findsNothing);
  }

  appTest('locked on start (7.4): nothing shows until unlocked', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('morrow is locked'), findsOneWidget);
    expect(find.text('Unlocking…'), findsOneWidget);
    expectNothingSensitive();

    await answer(tester, AuthOutcome.success);
    expect(find.text('Your journal'), findsOneWidget);
    expect(find.text('Synthetic private note'), findsOneWidget);
  });

  appTest('a cancelled unlock (7.5) offers Try again', (tester) async {
    await pump(tester);
    await answer(tester, AuthOutcome.cancelled);
    expect(find.text('Couldn’t unlock'), findsOneWidget);
    expect(
      find.text('Your journal stays locked until you unlock it.'),
      findsOneWidget,
    );
    expectNothingSensitive();

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(auth.reasons, hasLength(2));
    await answer(tester, AuthOutcome.success);
    expect(find.text('Your journal'), findsOneWidget);
  });

  appTest('lockout and a missing screen lock explain themselves', (
    tester,
  ) async {
    await pump(tester);
    await answer(tester, AuthOutcome.lockedOut);
    expect(find.text('Too many tries'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await answer(tester, AuthOutcome.notAvailable);
    expect(find.text('Set up a screen lock'), findsOneWidget);
    expectNothingSensitive();
  });

  appTest('leaving locks and hides everything; coming back asks again', (
    tester,
  ) async {
    await pump(tester);
    await answer(tester, AuthOutcome.success);
    expect(find.text('Synthetic private note'), findsOneWidget);

    // Inactive (for example the notification shade): covered, not locked.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(_cover, findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_cover, findsNothing);
    expect(find.text('Synthetic private note'), findsOneWidget);

    // Really away: locked, and the journal is gone, not just covered.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expectNothingSensitive();
    expect(find.text('morrow is locked'), findsOneWidget);
    expect(db.closed, isTrue, reason: 'locking closes the journal');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(auth.reasons, hasLength(2));
    expect(_cover, findsNothing);
  });

  appTest('no cover and no lock when app lock is off', (tester) async {
    settings.enabled = false;
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Your journal'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(_cover, findsNothing);
    expect(find.text('Your journal'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  appTest('Settings > App lock turns it on after confirming (7.1–7.3)', (
    tester,
  ) async {
    settings.enabled = false;
    await pump(tester);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('App lock'), findsOneWidget);
    // Weekly reminder and App lock are both off.
    expect(find.text('Off'), findsNWidgets(2));
    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();
    expect(find.text('Require unlock'), findsOneWidget);

    await tester.tap(find.text('Require unlock'));
    await tester.pump();
    expect(auth.reasons, ['Confirm to turn on app lock']);
    await answer(tester, AuthOutcome.cancelled);
    expect(settings.enabled, isFalse);
    expect(find.text('Off'), findsOneWidget);

    await tester.tap(find.text('Require unlock'));
    await tester.pump();
    await answer(tester, AuthOutcome.success);
    expect(settings.enabled, isTrue);
    expect(find.text('App lock is on'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('On'), findsOneWidget);
  });

  for (final scale in textScales) {
    appTest('locked screen at ${(scale * 100).toInt()}%', (tester) async {
      await pump(tester, textScale: scale);
      await answer(tester, AuthOutcome.cancelled);
      expect(tester.takeException(), isNull);
      expect(find.text('Try again'), findsOneWidget);
    });
  }
}
