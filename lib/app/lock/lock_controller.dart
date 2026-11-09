import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/diagnostic_log.dart';
import '../../core/security/device_auth.dart';
import '../providers.dart';

/// The application lock. Every sensitive screen and data provider exists
/// only while this is [unlocked].
enum AppLockState {
  /// Startup has not read the lock setting yet. Nothing sensitive is shown.
  uninitialised,
  locked,
  authenticating,
  unlocked,

  /// Unlocking cannot work right now (too many tries, no screen lock set
  /// up, the prompt failed, or the setting could not be read). The app
  /// stays locked; "Try again" is offered.
  error,
}

/// Why the last attempt did not unlock, for the locked screen (7.5).
enum LockProblem {
  didNotUnlock,
  lockedOut,
  notAvailable,
  promptFailed,
  settingUnreadable,
}

/// Decides whether the session is unlocked (M8).
///
/// - App lock is off by default. When it is on, the app is locked on cold
///   start and whenever it really goes to the background, and asks again
///   when it comes back.
/// - The unlock prompt's own pauses are ignored, so it never loops.
/// - So are the pauses of a system sheet morrow opened at the person's
///   request (save sheet, file picker, share sheet; see
///   [whileSystemSheet]), unless they are away longer than
///   [systemSheetAllowance] (decided 8 November 2026).
/// - Every attempt carries a session token: a result that arrives after
///   the app was locked again (or a newer attempt started) is discarded.
/// - Cancelling, failing or being locked out never turns app lock off.
/// - The unlocked state is never persisted.
class LockController extends Notifier<AppLockState> {
  int _session = 0;
  bool _promptShowing = false;

  /// How many of morrow's own system sheets are open.
  int _sheetsShowing = 0;

  /// When the app went to the background behind one of those sheets.
  DateTime? _leftForSheetAt;

  /// Away longer than this behind a system sheet (for example after
  /// pressing Home from the file picker) and morrow locks on return.
  static const Duration systemSheetAllowance = Duration(minutes: 1);

  /// Set when the app locked itself on going to the background, so it asks
  /// again once it is back. A cancelled prompt does not set it, so
  /// cancelling never re-opens the prompt by itself.
  bool _askOnResume = false;

  /// Why the last attempt did not unlock, or null.
  LockProblem? problem;

  /// Whether app lock is on (as last read or written).
  bool get enabled => ref.read(appLockEnabledProvider);

  set _enabled(bool on) => ref.read(appLockEnabledProvider.notifier).set(on);
  bool get _enabled => enabled;

  DeviceAuthenticator get _auth => ref.read(deviceAuthenticatorProvider);
  DiagnosticLog get _log => ref.read(diagnosticLogProvider);

  @override
  AppLockState build() {
    unawaited(Future.microtask(_start));
    return AppLockState.uninitialised;
  }

  Future<void> _start() async {
    final bool on;
    try {
      on = await ref.read(lockSettingsProvider).readEnabled();
    } on Object {
      // Fail closed: if the setting can't be read, don't assume it's off.
      _log.record(DiagnosticEvent.lockSettingFailed);
      problem = LockProblem.settingUnreadable;
      state = AppLockState.error;
      return;
    }
    _enabled = on;
    unawaited(ref.read(privacyShieldProvider).setRecentsPreviewHidden(on));
    if (!on) {
      state = AppLockState.unlocked;
      return;
    }
    state = AppLockState.locked;
    await unlock();
  }

  /// Shows the system prompt and unlocks on success. From the "setting
  /// unreadable" error, reads the setting again instead.
  Future<void> unlock() async {
    if (problem == LockProblem.settingUnreadable) {
      problem = null;
      state = AppLockState.uninitialised;
      await _start();
      return;
    }
    if (state == AppLockState.unlocked ||
        state == AppLockState.authenticating ||
        state == AppLockState.uninitialised) {
      return;
    }
    final token = ++_session;
    _askOnResume = false;
    state = AppLockState.authenticating;
    final outcome = await _prompt('Unlock morrow');
    // A newer lock or attempt has happened since: ignore this result.
    if (token != _session || state != AppLockState.authenticating) return;
    switch (outcome) {
      case AuthOutcome.success:
        problem = null;
        state = AppLockState.unlocked;
      case AuthOutcome.cancelled:
        // A deliberate choice (someone may be looking): back to the plain
        // locked screen, with no error.
        problem = null;
        state = AppLockState.locked;
      case AuthOutcome.failed:
        _log.record(DiagnosticEvent.unlockFailed);
        problem = LockProblem.didNotUnlock;
        state = AppLockState.locked;
      case AuthOutcome.lockedOut:
        _log.record(DiagnosticEvent.unlockLockedOut);
        problem = LockProblem.lockedOut;
        state = AppLockState.error;
      case AuthOutcome.notAvailable:
        _log.record(DiagnosticEvent.unlockUnavailable);
        problem = LockProblem.notAvailable;
        state = AppLockState.error;
      case AuthOutcome.error:
        _log.record(DiagnosticEvent.unlockFailed);
        problem = LockProblem.promptFailed;
        state = AppLockState.error;
    }
  }

  Future<AuthOutcome> _prompt(String reason) async {
    _promptShowing = true;
    try {
      return await _auth.authenticate(reason);
    } on Object {
      return AuthOutcome.error;
    } finally {
      _promptShowing = false;
    }
  }

  /// Locks now: disposes the unlocked scope (the router, the database and
  /// any unsaved changes) and invalidates any prompt still running.
  void lock() {
    _session++;
    problem = null;
    state = AppLockState.locked;
  }

  /// Runs [task], which opens a system sheet the person asked for, without
  /// the sheet's own backgrounding locking the app. Coming back after more
  /// than [systemSheetAllowance] still locks.
  Future<T> whileSystemSheet<T>(Future<T> Function() task) async {
    _sheetsShowing++;
    try {
      return await task();
    } finally {
      // The time away is checked on the next resume, which can arrive
      // before or after the sheet's result.
      _sheetsShowing--;
    }
  }

  bool _awayTooLong() {
    final left = _leftForSheetAt;
    return left != null &&
        ref.read(clockProvider).nowUtc().difference(left) >
            systemSheetAllowance;
  }

  /// Called for every app lifecycle change.
  void onLifecycle(AppLifecycleState s) {
    if (!_enabled || _promptShowing) return;
    // Coming back from one of morrow's sheets: only the resume matters
    // (the hidden and inactive steps on the way back are not a new trip to
    // the background). The resume can come before or after the sheet's
    // result.
    if (_leftForSheetAt != null &&
        (_sheetsShowing == 0 || s == AppLifecycleState.resumed)) {
      if (s != AppLifecycleState.resumed) return;
      final tooLong = _awayTooLong();
      _leftForSheetAt = null;
      if (tooLong && state == AppLockState.unlocked) {
        lock();
        unawaited(unlock());
      }
      return;
    }
    if (_sheetsShowing > 0) {
      if (s == AppLifecycleState.hidden || s == AppLifecycleState.paused) {
        _leftForSheetAt ??= ref.read(clockProvider).nowUtc();
      }
      return;
    }
    switch (s) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (state == AppLockState.unlocked) {
          lock();
          _askOnResume = true;
        }
      case AppLifecycleState.resumed:
        if (_askOnResume && state == AppLockState.locked) unawaited(unlock());
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  /// Before "Delete all data" (8.5): when app lock is on, the person must
  /// confirm it's them. With app lock off there is nothing to confirm.
  Future<AuthOutcome> confirmDeletion() async {
    if (!_enabled) return AuthOutcome.success;
    return _prompt('Confirm to delete all data');
  }

  /// After "Delete all data": app lock is off again (its setting was
  /// erased with everything else). Not a way to switch the lock off.
  void forgetAfterErase() {
    _enabled = false;
    problem = null;
    unawaited(ref.read(privacyShieldProvider).setRecentsPreviewHidden(false));
  }

  /// Turns app lock on or off after the user confirms with the system
  /// prompt (7.2, 7.6). The setting changes only on success and only once
  /// it is stored.
  Future<AuthOutcome> setEnabled(bool on) async {
    if (on == _enabled) return AuthOutcome.success;
    final outcome = await _prompt(
      on ? 'Confirm to turn on app lock' : 'Confirm to turn off app lock',
    );
    if (outcome != AuthOutcome.success) return outcome;
    try {
      await ref.read(lockSettingsProvider).writeEnabled(on);
    } on Object {
      return AuthOutcome.error;
    }
    _enabled = on;
    _log.record(
      on ? DiagnosticEvent.lockTurnedOn : DiagnosticEvent.lockTurnedOff,
    );
    unawaited(ref.read(privacyShieldProvider).setRecentsPreviewHidden(on));
    return AuthOutcome.success;
  }
}

/// Whether app lock is on, for screens to watch. Written only by
/// [LockController].
class AppLockEnabled extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}

final appLockEnabledProvider = NotifierProvider<AppLockEnabled, bool>(
  AppLockEnabled.new,
);

final lockControllerProvider = NotifierProvider<LockController, AppLockState>(
  LockController.new,
);
