class LocationRecord {
  const LocationRecord({
    required this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
  });

  final String id;
  final String sessionId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
}
