import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/location_record.dart';
import '../../domain/entities/tracking_session.dart';
import '../../domain/repositories/location_repository.dart';

class LocationHiveDataSource {
  LocationHiveDataSource({
    required Box<Map> recordsBox,
    required Box<Map> sessionsBox,
    required Box settingsBox,
  })  : _recordsBox = recordsBox,
        _sessionsBox = sessionsBox,
        _settingsBox = settingsBox;

  final Box<Map> _recordsBox;
  final Box<Map> _sessionsBox;
  final Box _settingsBox;

  static const _activeSessionKey = 'active_session_id';

  Future<void> init() async {}

  Future<void> saveRecord(LocationRecord record) async {
    await _recordsBox.put(record.id, {
      'id': record.id,
      'sessionId': record.sessionId,
      'latitude': record.latitude,
      'longitude': record.longitude,
      'timestamp': record.timestamp.toIso8601String(),
      'accuracy': record.accuracy,
    });
  }

  List<LocationRecord> getRecordsForSession(String sessionId) {
    return _recordsBox.values
        .where((map) => map['sessionId'] == sessionId)
        .map(_mapToRecord)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<LocationRecord> getAllRecords() {
    return _recordsBox.values.map(_mapToRecord).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> clearSessionRecords(String sessionId) async {
    final keysToDelete = _recordsBox.keys.where((key) {
      final map = _recordsBox.get(key);
      return map != null && map['sessionId'] == sessionId;
    }).toList();
    await _recordsBox.deleteAll(keysToDelete);
  }

  Future<void> saveSession(TrackingSession session) async {
    await _sessionsBox.put(session.id, {
      'id': session.id,
      'startedAt': session.startedAt.toIso8601String(),
      'stoppedAt': session.stoppedAt?.toIso8601String(),
      'isActive': session.isActive,
    });
    if (session.isActive) {
      await _settingsBox.put(_activeSessionKey, session.id);
    }
  }

  TrackingSession? getActiveSession() {
    final activeId = _settingsBox.get(_activeSessionKey) as String?;
    if (activeId == null) return null;
    final map = _sessionsBox.get(activeId);
    if (map == null) return null;
    return _mapToSession(map);
  }

  List<TrackingSession> getAllSessions() {
    return _sessionsBox.values.map(_mapToSession).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> clearActiveSession() async {
    await _settingsBox.delete(_activeSessionKey);
  }

  LocationRecord _mapToRecord(Map map) {
    return LocationRecord(
      id: map['id'] as String,
      sessionId: map['sessionId'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      accuracy: (map['accuracy'] as num).toDouble(),
    );
  }

  TrackingSession _mapToSession(Map map) {
    return TrackingSession(
      id: map['id'] as String,
      startedAt: DateTime.parse(map['startedAt'] as String),
      stoppedAt: map['stoppedAt'] != null
          ? DateTime.parse(map['stoppedAt'] as String)
          : null,
      isActive: map['isActive'] as bool? ?? false,
    );
  }
}

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._dataSource);

  final LocationHiveDataSource _dataSource;

  @override
  Future<void> saveRecord(LocationRecord record) =>
      _dataSource.saveRecord(record);

  @override
  Future<List<LocationRecord>> getRecordsForSession(String sessionId) async =>
      _dataSource.getRecordsForSession(sessionId);

  @override
  Future<List<LocationRecord>> getAllRecords() async =>
      _dataSource.getAllRecords();

  @override
  Future<void> clearSessionRecords(String sessionId) =>
      _dataSource.clearSessionRecords(sessionId);
}

class TrackingSessionRepositoryImpl implements TrackingSessionRepository {
  TrackingSessionRepositoryImpl(this._dataSource);

  final LocationHiveDataSource _dataSource;

  @override
  Future<void> saveSession(TrackingSession session) =>
      _dataSource.saveSession(session);

  @override
  Future<TrackingSession?> getActiveSession() async =>
      _dataSource.getActiveSession();

  @override
  Future<List<TrackingSession>> getAllSessions() async =>
      _dataSource.getAllSessions();

  @override
  Future<void> clearActiveSession() => _dataSource.clearActiveSession();
}

Future<LocationHiveDataSource> initHiveDataSource() async {
  await Hive.initFlutter();
  final recordsBox =
      await Hive.openBox<Map>(AppConstants.hiveBoxName);
  final sessionsBox =
      await Hive.openBox<Map>(AppConstants.hiveSessionBoxName);
  final settingsBox =
      await Hive.openBox(AppConstants.hiveSettingsBoxName);
  final dataSource = LocationHiveDataSource(
    recordsBox: recordsBox,
    sessionsBox: sessionsBox,
    settingsBox: settingsBox,
  );
  await dataSource.init();
  return dataSource;
}
