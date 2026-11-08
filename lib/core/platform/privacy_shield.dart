import 'package:flutter/services.dart';

/// Hides morrow's thumbnail in the phone's recent-apps view while app lock
/// is on. Android 13+ only (setRecentsScreenshotEnabled); elsewhere a no-op,
/// and the app's own privacy cover is shown instead. Screenshots stay
/// allowed.
abstract interface class PrivacyShield {
  Future<void> setRecentsPreviewHidden(bool hidden);
}

class PlatformPrivacyShield implements PrivacyShield {
  const PlatformPrivacyShield();

  static const MethodChannel _channel = MethodChannel('morrow/privacy');

  @override
  Future<void> setRecentsPreviewHidden(bool hidden) async {
    try {
      await _channel.invokeMethod<void>('setRecentsPreviewHidden', hidden);
    } on MissingPluginException {
      // Not on Android (for example iOS or tests).
    } on PlatformException {
      // Best effort; the in-app cover still applies.
    }
  }
}
