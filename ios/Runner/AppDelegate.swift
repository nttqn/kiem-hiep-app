import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Keep the screen on while fighting (1.13.0).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KhScreen") {
      let channel = FlutterMethodChannel(name: "kh/screen", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "keepOn" {
          UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
          result(nil)
        } else if call.method == "openUrl" {
          // Bảng tin (1.16.3): a notice's button (App Store or web page).
          guard let s = call.arguments as? String, let url = URL(string: s) else {
            result(false)
            return
          }
          UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
