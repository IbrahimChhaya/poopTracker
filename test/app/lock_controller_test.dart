import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/app/lock/lock_controller.dart';
import 'package:poop_tracker/app/providers.dart';
import 'package:poop_tracker/core/diagnostics/diagnostic_log.dart';
import 'package:poop_tracker/core/security/device_auth.dart';

import '../support/fake_diagnostics.dart';
import '../support/fake_lock.dart';

void main() {
  late FakeAuthenticator auth;
  late FakeLockSettings settings;
  late FakePrivacyShield shield;
  late MemoryDiagnosticLog log;
  late ProviderContainer c;

  void make({bool enabled = false, bool hold = false}) {
    auth = FakeAuthenticator(hold: hold);
    settings = FakeLockSettings(enabled: enabled);
    shield = FakePrivacyShield();
    log = MemoryDiagnosticLog();
    c = ProviderContainer(
      overrides: [
        deviceAuthenticatorProvider.overrideWithValue(auth),
        lockSettingsProvider.overrideWithValue(settings),
        privacyShieldProvider.overrideWithValue(shield),
        diagnosticLogProvider.overrideWithValue(log),
      ],
    );
    addTearDown(c.dispose);
    c.listen(lockControllerProvider, (_, _) {});
  }

  AppLockState state() => c.read(lockControllerProvider);
  LockController lock() => c.read(lockControllerProvider.notifier);
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('starting up', () {
    test('lock off: uninitialised, then unlocked with no prompt', () async {
      make();
      expect(state(), AppLockState.uninitialised);
      await settle();
      expect(state(), AppLockState.unlocked);
      expect(auth.reasons, isEmpty);
      expect(shield.calls, [false]);
    });

    test('lock on: asks straight away, unlocked on success', () async {
      make(enabled: true, hold: true);
      await settle();
      expect(state(), AppLockState.authenticating);
      expect(auth.reasons, ['Unlock morrow']);
      expect(shield.calls, [true]);
      auth.complete(AuthOutcome.success);
      await settle();
      expect(state(), AppLockState.unlocked);
      expect(lock().problem, isNull);
    });

    test(
      'an unreadable setting fails closed; Try again reads it again',
      () async {
        make(enabled: true);
        settings.failRead = true;
        await settle();
        expect(state(), AppLockState.error);
        expect(lock().problem, LockProblem.settingUnreadable);
        expect(log.events, [DiagnosticEvent.lockSettingFailed]);

        settings.failRead = false;
        await lock().unlock();
        await settle();
        expect(state(), AppLockState.unlocked);
      },
    );
  });

  group('when unlocking does not work, the lock stays on', () {
    for (final (outcome, expectedState, problem, event) in [
      (
        AuthOutcome.cancelled,
        AppLockState.locked,
        LockProblem.didNotUnlock,
        DiagnosticEvent.unlockFailed,
      ),
      (
        AuthOutcome.failed,
        AppLockState.locked,
        LockProblem.didNotUnlock,
        DiagnosticEvent.unlockFailed,
      ),
      (
        AuthOutcome.lockedOut,
        AppLockState.error,
        LockProblem.lockedOut,
        DiagnosticEvent.unlockLockedOut,
      ),
      (
        AuthOutcome.notAvailable,
        AppLockState.error,
        LockProblem.notAvailable,
        DiagnosticEvent.unlockUnavailable,
      ),
      (
        AuthOutcome.error,
        AppLockState.error,
        LockProblem.promptFailed,
        DiagnosticEvent.unlockFailed,
      ),
    ]) {
      test(outcome.name, () async {
        make(enabled: true, hold: true);
        await settle();
        auth.complete(outcome);
        await settle();
        expect(state(), expectedState);
        expect(lock().problem, problem);
        expect(lock().enabled, isTrue);
        expect(settings.enabled, isTrue);
        expect(log.events, [event]);

        // Try again works once the prompt succeeds.
        final retry = lock().unlock();
        auth.complete(AuthOutcome.success);
        await retry;
        expect(state(), AppLockState.unlocked);
      });
    }

    test('a cancelled prompt is not reopened by coming back', () async {
      make(enabled: true, hold: true);
      await settle();
      auth.complete(AuthOutcome.cancelled);
      await settle();
      lock().onLifecycle(AppLifecycleState.resumed);
      await settle();
      expect(auth.reasons, hasLength(1));
      expect(state(), AppLockState.locked);
    });
  });

  group('backgrounding', () {
    Future<void> unlocked() async {
      make(enabled: true);
      await settle();
      expect(state(), AppLockState.unlocked);
    }

    test('going to the background locks; coming back asks again', () async {
      await unlocked();
      lock().onLifecycle(AppLifecycleState.inactive);
      expect(state(), AppLockState.unlocked, reason: 'inactive is not away');
      lock().onLifecycle(AppLifecycleState.hidden);
      expect(state(), AppLockState.locked);
      lock().onLifecycle(AppLifecycleState.paused);
      expect(state(), AppLockState.locked);
      auth.hold = true;
      lock().onLifecycle(AppLifecycleState.resumed);
      await settle();
      expect(state(), AppLockState.authenticating);
      expect(auth.reasons, ['Unlock morrow', 'Unlock morrow']);
      auth.complete(AuthOutcome.success);
      await settle();
      expect(state(), AppLockState.unlocked);
    });

    test('the prompt’s own pauses are ignored, so it never loops', () async {
      make(enabled: true, hold: true);
      await settle();
      // The passcode screen pauses the app on some phones.
      lock()
        ..onLifecycle(AppLifecycleState.inactive)
        ..onLifecycle(AppLifecycleState.hidden)
        ..onLifecycle(AppLifecycleState.paused)
        ..onLifecycle(AppLifecycleState.resumed);
      expect(state(), AppLockState.authenticating);
      auth.complete(AuthOutcome.success);
      await settle();
      expect(state(), AppLockState.unlocked);
      expect(auth.reasons, hasLength(1));
    });

    test('a stale success after locking again is discarded', () async {
      make(enabled: true, hold: true);
      await settle();
      expect(state(), AppLockState.authenticating);
      lock().lock();
      auth.complete(AuthOutcome.success);
      await settle();
      expect(state(), AppLockState.locked);
    });

    test('nothing happens on backgrounding when the lock is off', () async {
      make();
      await settle();
      lock().onLifecycle(AppLifecycleState.paused);
      expect(state(), AppLockState.unlocked);
    });
  });

  group('turning app lock on and off', () {
    test('asks first; stores it; hides the recent-apps preview', () async {
      make();
      await settle();
      expect(await lock().setEnabled(true), AuthOutcome.success);
      expect(auth.reasons, ['Confirm to turn on app lock']);
      expect(settings.enabled, isTrue);
      expect(lock().enabled, isTrue);
      expect(c.read(appLockEnabledProvider), isTrue);
      expect(shield.calls.last, isTrue);
      expect(log.events, [DiagnosticEvent.lockTurnedOn]);
      expect(state(), AppLockState.unlocked, reason: 'no relock on turning on');

      expect(await lock().setEnabled(false), AuthOutcome.success);
      expect(auth.reasons.last, 'Confirm to turn off app lock');
      expect(settings.enabled, isFalse);
      expect(shield.calls.last, isFalse);
    });

    test('a cancelled confirmation changes nothing', () async {
      make(enabled: true);
      await settle();
      auth.next = AuthOutcome.cancelled;
      expect(await lock().setEnabled(false), AuthOutcome.cancelled);
      expect(settings.enabled, isTrue);
      expect(lock().enabled, isTrue);
    });

    test('a failed save changes nothing', () async {
      make();
      await settle();
      settings.failWrite = true;
      expect(await lock().setEnabled(true), AuthOutcome.error);
      expect(lock().enabled, isFalse);
    });

    test('its own prompt does not lock the app', () async {
      make();
      await settle();
      lock().onLifecycle(AppLifecycleState.paused);
      auth.hold = true;
      final turningOn = lock().setEnabled(true);
      lock().onLifecycle(AppLifecycleState.paused);
      auth.complete(AuthOutcome.success);
      await turningOn;
      expect(state(), AppLockState.unlocked);
    });
  });
}
