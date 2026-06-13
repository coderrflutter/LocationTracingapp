import '../entities/location_record.dart';
import '../entities/tracking_session.dart';

abstract class LocationRepository {
  Future<void> saveRecord(LocationRecord record);

  Future<List<LocationRecord>> getRecordsForSession(String sessionId);

  Future<List<LocationRecord>> getAllRecords();

  Future<void> clearSessionRecords(String sessionId);
}

abstract class TrackingSessionRepository {
  Future<void> saveSession(TrackingSession session);

  Future<TrackingSession?> getActiveSession();

  Future<List<TrackingSession>> getAllSessions();

  Future<void> clearActiveSession();
}
