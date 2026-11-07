import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The application lock. Every sensitive screen and data provider exists
/// only while this is [unlocked].
enum AppLockState {
  /// Startup has not decided yet. Nothing sensitive is shown.
  uninitialised,
  locked,
  authenticating,
  unlocked,

  /// Authentication could not run (for example, no credentials enrolled).
  /// The app stays locked.
  error,
}

/// Decides whether the session is unlocked.
///
/// M4: app lock is not available yet, so the session is unlocked as soon as
/// the app starts. M8 adds the optional device-authentication lock here.
/// The unlocked state is never persisted.
class LockController extends Notifier<AppLockState> {
  @override
  AppLockState build() => AppLockState.unlocked;
}

final lockControllerProvider = NotifierProvider<LockController, AppLockState>(
  LockController.new,
);
