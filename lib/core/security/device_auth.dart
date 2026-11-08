import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// How an authentication attempt ended.
enum AuthOutcome {
  success,

  /// Dismissed by the user or the system. Nothing changes.
  cancelled,

  /// The biometric or passcode did not match.
  failed,

  /// Too many attempts; the phone has locked authentication for a while.
  lockedOut,

  /// No screen lock is set up, or the phone cannot authenticate at all.
  notAvailable,

  /// The prompt could not run.
  error,
}

/// The phone's own biometric / device-credential prompt. Accepting a result
/// is the app's decision; this does not bind the database key to
/// authentication (see the security notes in the plan).
abstract interface class DeviceAuthenticator {
  /// Shows the system prompt with [reason].
  Future<AuthOutcome> authenticate(String reason);

  /// Dismisses a prompt that is still showing, if the platform allows it.
  Future<void> cancel();
}

/// [DeviceAuthenticator] using local_auth 3: biometrics with the phone's
/// PIN, pattern or passcode as fallback (never biometrics only).
class LocalDeviceAuthenticator implements DeviceAuthenticator {
  LocalDeviceAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return AuthOutcome.notAvailable;
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // The prompt survives the app being briefly backgrounded by the
        // system (for example the passcode screen on some phones).
        persistAcrossBackgrounding: true,
      );
      return ok ? AuthOutcome.success : AuthOutcome.failed;
    } on LocalAuthException catch (e) {
      return outcomeFor(e.code);
    } on PlatformException {
      return AuthOutcome.error;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _auth.stopAuthentication();
    } on Object {
      // Nothing to cancel.
    }
  }
}

/// Maps local_auth's error codes to outcomes.
AuthOutcome outcomeFor(LocalAuthExceptionCode code) => switch (code) {
  LocalAuthExceptionCode.userCanceled ||
  LocalAuthExceptionCode.systemCanceled ||
  LocalAuthExceptionCode.timeout ||
  LocalAuthExceptionCode.userRequestedFallback => AuthOutcome.cancelled,
  LocalAuthExceptionCode.temporaryLockout ||
  LocalAuthExceptionCode.biometricLockout => AuthOutcome.lockedOut,
  LocalAuthExceptionCode.noCredentialsSet ||
  LocalAuthExceptionCode.noBiometricsEnrolled ||
  LocalAuthExceptionCode.noBiometricHardware => AuthOutcome.notAvailable,
  LocalAuthExceptionCode.authInProgress ||
  LocalAuthExceptionCode.uiUnavailable ||
  LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
  LocalAuthExceptionCode.deviceError ||
  LocalAuthExceptionCode.unknownError => AuthOutcome.error,
};
