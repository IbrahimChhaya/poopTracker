import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/database/bootstrap.dart';
import 'package:poop_tracker/core/security/device_auth.dart';

import '../../support/app_harness.dart';
import '../../support/fake_lock.dart';
import '../../support/harness.dart';

void main() {
  late TrackingDatabase db;
  late FakeWelcomeStore welcome;

  setUp(() {
    db = TrackingDatabase();
    welcome = FakeWelcomeStore(seen: false);
  });

  Future<AppUnderTest> pumpNew(
    WidgetTester tester, {
    bool createdNew = true,
    FakeAuthenticator? authenticator,
    FakeLockSettings? lockSettings,
    double textScale = 1,
  }) async {
    final app = await pumpMorrowApp(
      tester,
      [StartupReady(db, createdNew: createdNew)],
      welcome: welcome,
      authenticator: authenticator,
      lockSettings: lockSettings,
      textScale: textScale,
      size: textScale > 1 ? smallPhone : figmaPhone,
    );
    await tester.pumpAndSettle();
    return app;
  }

  /// Taps the visible control (the tour builds its neighbouring pages too).
  Future<void> tap(WidgetTester tester, String label) async {
    if (find.text(label).hitTestable().evaluate().isEmpty) {
      await tester.ensureVisible(find.text(label).first);
      await tester.pumpAndSettle();
    }
    final f = find.text(label).hitTestable();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Finder visible(String text) => find.text(text).hitTestable();

  appTest('a new journal opens on the welcome (1.1)', (tester) async {
    await pumpNew(tester);
    expect(find.text('Your quiet journal.'), findsOneWidget);
    expect(
      find.text(
        'Log an entry in one tap and look back week by week. Encrypted on '
        'this phone, with no account.',
      ),
      findsOneWidget,
    );
    expect(find.text('Your journal'), findsNothing);
    // The preview is decoration, not a control.
    expect(find.bySemanticsLabel('Quiet evening'), findsNothing);
  });

  appTest('an existing journal never shows it, seen or not', (tester) async {
    await pumpNew(tester, createdNew: false);
    expect(find.text('Your quiet journal.'), findsNothing);
    expect(find.text('Your journal'), findsOneWidget);
  });

  appTest('once seen, it never shows again', (tester) async {
    welcome.seen = true;
    await pumpNew(tester);
    expect(find.text('Your quiet journal.'), findsNothing);
    expect(find.text('Your journal'), findsOneWidget);
  });

  appTest('if secure storage can’t be read, the journal opens', (tester) async {
    welcome.failRead = true;
    await pumpNew(tester);
    expect(find.text('Your journal'), findsOneWidget);
  });

  appTest('Skip goes to the journal, with the one-time hint (1.6)', (
    tester,
  ) async {
    await pumpNew(tester);
    await tap(tester, 'Get started');
    expect(visible('One tap, and it’s logged.'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 1 of 4'), findsOneWidget);
    await tap(tester, 'Skip');
    expect(find.text('Your journal'), findsOneWidget);
    expect(welcome.seen, isTrue);
    expect(find.text('Start with one tap'), findsOneWidget);
    await tap(tester, 'Got it');
    expect(find.text('Start with one tap'), findsNothing);
  });

  appTest('the hint goes once the first entry is added', (tester) async {
    await pumpNew(tester);
    await tap(tester, 'Get started');
    await tap(tester, 'Skip');
    expect(find.text('Start with one tap'), findsOneWidget);
    await tap(tester, 'Add an entry');
    await tap(tester, 'Done');
    expect(find.text('Start with one tap'), findsNothing);
  });

  appTest('the four pages, with real switches and app lock (1.2–1.5)', (
    tester,
  ) async {
    final lock = FakeLockSettings();
    await pumpNew(
      tester,
      authenticator: FakeAuthenticator(),
      lockSettings: lock,
    );
    await tap(tester, 'Get started');
    await tap(tester, 'Next');

    // 1.3: the real settings, off until turned on.
    expect(visible('Add more, only if you want.'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 2 of 4'), findsOneWidget);
    await tap(tester, 'Stool form');
    final settings = await db.select(db.appSettings).getSingle();
    expect(settings.showStoolForm, isTrue);
    expect(settings.showContext, isFalse);
    expect(find.text('Type 4'), findsWidgets);
    await tap(tester, 'Next');

    expect(visible('See your trends.'), findsOneWidget);
    // The preview is decoration: not read out.
    expect(find.bySemanticsLabel('Weekly check-in'), findsNothing);
    await tap(tester, 'Next');

    // 1.5: no Skip on the last page; app lock uses the phone's prompt.
    expect(visible('Private by design.'), findsOneWidget);
    expect(visible('Skip'), findsNothing);
    await tap(tester, 'App lock');
    expect(lock.enabled, isTrue);
    expect(find.text('App lock is on'), findsOneWidget);

    await tap(tester, 'Start your journal');
    expect(find.text('Your journal'), findsOneWidget);
    expect(welcome.seen, isTrue);
    expect(find.text('Start with one tap'), findsOneWidget);
  });

  appTest('no screen lock: app lock stays off and says why (1.5d)', (
    tester,
  ) async {
    final lock = FakeLockSettings();
    await pumpNew(
      tester,
      authenticator: FakeAuthenticator(next: AuthOutcome.notAvailable),
      lockSettings: lock,
    );
    await tap(tester, 'Get started');
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'Next');
    }
    await tap(tester, 'App lock');
    expect(lock.enabled, isFalse);
    expect(visible('Not available on this phone yet'), findsOneWidget);
    expect(
      find.textContaining('Set up a screen lock in your phone’s settings'),
      findsOneWidget,
    );
  });

  appTest('cancelling the prompt changes nothing and says nothing', (
    tester,
  ) async {
    final lock = FakeLockSettings();
    await pumpNew(
      tester,
      authenticator: FakeAuthenticator(next: AuthOutcome.cancelled),
      lockSettings: lock,
    );
    await tap(tester, 'Get started');
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'Next');
    }
    await tap(tester, 'App lock');
    expect(lock.enabled, isFalse);
    expect(find.text('App lock is on'), findsNothing);
    expect(find.textContaining('Set up a screen lock'), findsNothing);
  });

  appTest('system back steps back a page, then to the welcome', (tester) async {
    await pumpNew(tester);
    await tap(tester, 'Get started');
    await tap(tester, 'Next');
    expect(visible('Add more, only if you want.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(visible('One tap, and it’s logged.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your quiet journal.'), findsOneWidget);
    expect(welcome.seen, isFalse);
  });

  appTest('Restore from a backup opens 9.5; back returns to the welcome', (
    tester,
  ) async {
    await pumpNew(tester);
    await tap(tester, 'Restore from a backup');
    expect(find.text('Choose backup file'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your quiet journal.'), findsOneWidget);
  });

  appTest('Settings > Welcome tour replays it and comes back', (tester) async {
    welcome.seen = true;
    await pumpNew(tester);
    await tap(tester, 'Settings');
    await tester.scrollUntilVisible(
      find.text('Welcome tour'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(tester, 'Welcome tour');
    expect(visible('One tap, and it’s logged.'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'Next');
    }
    await tap(tester, 'Done');
    expect(find.text('Welcome tour'), findsOneWidget);
    expect(find.text('Start with one tap'), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    appTest('welcome and tour fit at ${scale}x', (tester) async {
      await pumpNew(tester, textScale: scale);
      expect(tester.takeException(), isNull, reason: 'welcome');
      await tap(tester, 'Get started');
      for (var i = 0; i < 3; i++) {
        expect(tester.takeException(), isNull, reason: 'page ${i + 1}');
        await tap(tester, 'Next');
      }
      expect(tester.takeException(), isNull, reason: 'page 4');
      await tap(tester, 'Start your journal');
      expect(find.text('Your journal'), findsOneWidget);
    });
  }
}
