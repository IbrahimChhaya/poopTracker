import 'dart:async';

import 'package:poop_tracker/core/platform/privacy_shield.dart';
import 'package:poop_tracker/core/security/device_auth.dart';
import 'package:poop_tracker/core/security/key_store.dart';
import 'package:poop_tracker/core/security/lock_settings.dart';
import 'package:poop_tracker/core/security/welcome_store.dart';

/// Authenticator whose answers are scripted. With [hold] set, each prompt
/// waits until [complete] is called, so tests can act while it is showing.
class FakeAuthenticator implements DeviceAuthenticator {
  FakeAuthenticator({this.next = AuthOutcome.success, this.hold = false});

  AuthOutcome next;
  bool hold;
  final List<String> reasons = [];
  Completer<AuthOutcome>? _pending;
  int cancels = 0;

  bool get showing => _pending != null;

  @override
  Future<AuthOutcome> authenticate(String reason) {
    reasons.add(reason);
    if (!hold) return Future.value(next);
    final c = Completer<AuthOutcome>();
    _pending = c;
    return c.future;
  }

  /// Answers the prompt that is showing.
  void complete([AuthOutcome? outcome]) {
    final c = _pending!;
    _pending = null;
    c.complete(outcome ?? next);
  }

  @override
  Future<void> cancel() async => cancels++;
}

class FakeLockSettings implements LockSettingsStore {
  FakeLockSettings({this.enabled = false});

  bool enabled;
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<bool> readEnabled() async {
    if (failRead) throw const KeyStoreException('read app lock');
    return enabled;
  }

  @override
  Future<void> writeEnabled(bool on) async {
    if (failWrite) throw const KeyStoreException('write app lock');
    enabled = on;
  }
}

class FakePrivacyShield implements PrivacyShield {
  final List<bool> calls = [];

  final List<String> excluded = [];

  @override
  Future<void> setRecentsPreviewHidden(bool hidden) async => calls.add(hidden);

  @override
  Future<void> excludeFromBackup(String directoryPath) async =>
      excluded.add(directoryPath);
}

/// The welcome's seen flag. Seen by default, so tests that start a new
/// journal go straight to it; welcome tests start unseen.
class FakeWelcomeStore implements WelcomeStore {
  FakeWelcomeStore({this.seen = true});

  bool seen;
  bool failRead = false;

  @override
  Future<bool> readSeen() async {
    if (failRead) throw const KeyStoreException('read welcome');
    return seen;
  }

  @override
  Future<void> markSeen() async => seen = true;
}
