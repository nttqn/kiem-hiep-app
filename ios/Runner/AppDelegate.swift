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
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
