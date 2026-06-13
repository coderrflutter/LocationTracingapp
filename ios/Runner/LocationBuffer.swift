import Foundation

/// Persists location readings when the Flutter engine is not running.
enum LocationBuffer {
    private static let key = "buffered_locations"

    static func append(
        sessionId: String,
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        timestamp: Int64
    ) {
        var items = loadRaw()
        let entry: [String: Any] = [
            "id": UUID().uuidString,
            "sessionId": sessionId,
            "latitude": latitude,
            "longitude": longitude,
            "accuracy": accuracy,
            "timestamp": timestamp,
        ]
        items.append(entry)
        UserDefaults.standard.set(items, forKey: key)
    }

    static func flush() -> [[String: Any]] {
        let items = loadRaw()
        UserDefaults.standard.set([], forKey: key)
        return items
    }

    private static func loadRaw() -> [[String: Any]] {
        UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
    }
}
