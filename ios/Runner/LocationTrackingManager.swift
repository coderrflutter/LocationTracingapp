import CoreLocation
import Flutter
import UIKit

/// Manages background GPS updates every 60 seconds on iOS.
final class LocationTrackingManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTrackingManager()

    private let manager = CLLocationManager()
    private var sessionId: String = ""
    private var intervalSeconds: TimeInterval = 60
    private var lastRecordedAt: Date?
    private var eventSink: FlutterEventSink?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        if #available(iOS 11.0, *) {
            manager.showsBackgroundLocationIndicator = true
        }
    }

    func setEventSink(_ sink: FlutterEventSink?) {
        eventSink = sink
    }

    func start(sessionId: String, intervalSeconds: Int) {
        self.sessionId = sessionId
        self.intervalSeconds = TimeInterval(intervalSeconds)
        lastRecordedAt = nil

        UserDefaults.standard.set(true, forKey: TrackingPrefs.isActive)
        UserDefaults.standard.set(sessionId, forKey: TrackingPrefs.sessionId)
        UserDefaults.standard.set(intervalSeconds, forKey: TrackingPrefs.interval)

        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        lastRecordedAt = nil
        UserDefaults.standard.set(false, forKey: TrackingPrefs.isActive)
    }

    func isActive() -> Bool {
        UserDefaults.standard.bool(forKey: TrackingPrefs.isActive)
    }

    func resumeIfNeeded() {
        guard isActive() else { return }
        let sessionId = UserDefaults.standard.string(forKey: TrackingPrefs.sessionId) ?? UUID().uuidString
        let interval = UserDefaults.standard.integer(forKey: TrackingPrefs.interval)
        start(sessionId: sessionId, intervalSeconds: interval == 0 ? 60 : interval)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let now = Date()
        if let last = lastRecordedAt, now.timeIntervalSince(last) < intervalSeconds {
            return
        }
        lastRecordedAt = now

        let payload: [String: Any] = [
            "id": UUID().uuidString,
            "sessionId": sessionId,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000),
        ]

        LocationBuffer.append(
            sessionId: sessionId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: Int64(location.timestamp.timeIntervalSince1970 * 1000)
        )

        eventSink?(payload)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location errors are expected indoors; the next update will retry.
        NSLog("LocationTrackingManager error: \(error.localizedDescription)")
    }
}

private enum TrackingPrefs {
    static let isActive = "tracking_is_active"
    static let sessionId = "tracking_session_id"
    static let interval = "tracking_interval_seconds"
}
