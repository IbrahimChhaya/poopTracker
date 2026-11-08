import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: lets the weekly reminder show while the
    // app is open and report taps.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // "morrow/privacy": marks the journal and diagnostics folders as
    // excluded from iCloud and device backups (M10). Not compiled or run on
    // a device yet: verify in the iOS device check.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MorrowPrivacy") {
      let channel = FlutterMethodChannel(
        name: "morrow/privacy", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "excludeFromBackup":
          guard let path = call.arguments as? String else {
            result(FlutterError(code: "bad_args", message: nil, details: nil))
            return
          }
          var url = URL(fileURLWithPath: path, isDirectory: true)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          do {
            try url.setResourceValues(values)
            result(nil)
          } catch {
            result(FlutterError(code: "failed", message: nil, details: nil))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
