import Flutter
import UIKit
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let awakeChannel = FlutterMethodChannel(
        name: "app.soulbuddy/screen_awake",
        binaryMessenger: controller.binaryMessenger
      )
      awakeChannel.setMethodCallHandler { call, result in
        if call.method == "setEnabled", let enabled = call.arguments as? Bool {
          UIApplication.shared.isIdleTimerDisabled = enabled
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      let channel = FlutterMethodChannel(
        name: "app.soulbuddy/prayer_audio",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        let session = AVAudioSession.sharedInstance()
        switch call.method {
        case "currentRoute":
          let headphones = session.currentRoute.outputs.contains {
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .usbAudio].contains($0.portType)
          }
          result(headphones ? "headphones" : "unknown")
        case "interruptionsAllowed":
          // iOS exposes neither the silent switch nor Focus state reliably.
          result(false)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
