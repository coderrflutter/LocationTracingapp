import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    LocationTrackingManager.shared.resumeIfNeeded()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    let trackingChannel = FlutterMethodChannel(
      name: "com.example.backround_location_tracking/tracking",
      binaryMessenger: messenger
    )
    trackingChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "startTracking":
        guard
          let args = call.arguments as? [String: Any],
          let sessionId = args["sessionId"] as? String
        else {
          result(FlutterError(code: "INVALID", message: "sessionId required", details: nil))
          return
        }
        let interval = args["intervalSeconds"] as? Int ?? 60
        LocationTrackingManager.shared.start(sessionId: sessionId, intervalSeconds: interval)
        result(true)

      case "stopTracking":
        LocationTrackingManager.shared.stop()
        result(true)

      case "isTrackingActive":
        result(LocationTrackingManager.shared.isActive())

      case "getBufferedLocations":
        result(LocationBuffer.flush())

      case "requestBatteryOptimizationExemption":
        // No Android-style battery optimization on iOS.
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let batteryChannel = FlutterMethodChannel(
      name: "com.example.backround_location_tracking/battery",
      binaryMessenger: messenger
    )
    batteryChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getBatteryLevel":
        result(Self.readBatteryLevel())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(
      name: "com.example.backround_location_tracking/location_events",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(LocationEventStreamHandler())
  }

  /// Reads battery level via UIDevice (no third-party plugins).
  private static func readBatteryLevel() -> Int {
    UIDevice.current.isBatteryMonitoringEnabled = true
    let level = UIDevice.current.batteryLevel
    if level < 0 {
      return -1
    }
    return Int(level * 100)
  }
}

/// Forwards native location events to Flutter.
final class LocationEventStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    LocationTrackingManager.shared.setEventSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    LocationTrackingManager.shared.setEventSink(nil)
    return nil
  }
}
