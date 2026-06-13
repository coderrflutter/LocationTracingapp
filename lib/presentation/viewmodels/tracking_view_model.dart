import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/location_record.dart';
import '../../domain/entities/tracking_session.dart';
import '../../domain/repositories/location_repository.dart';
import '../../services/background_tracking_service.dart';
import '../../services/battery_service.dart';

/// Coordinates tracking lifecycle, persistence, and UI state.
class TrackingViewModel extends ChangeNotifier {
  TrackingViewModel({
    required LocationRepository locationRepository,
    required TrackingSessionRepository sessionRepository,
    required BackgroundTrackingService backgroundService,
    required BatteryService batteryService,
    required LocationService locationService,
    Uuid? uuid,
  })  : _locationRepository = locationRepository,
        _sessionRepository = sessionRepository,
        _backgroundService = backgroundService,
        _batteryService = batteryService,
        _locationService = locationService,
        _uuid = uuid ?? const Uuid();

  final LocationRepository _locationRepository;
  final TrackingSessionRepository _sessionRepository;
  final BackgroundTrackingService _backgroundService;
  final BatteryService _batteryService;
  final LocationService _locationService;
  final Uuid _uuid;

  bool _isTracking = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  int _batteryLevel = -1;
  TrackingSession? _activeSession;
  List<LocationRecord> _records = [];
  StreamSubscription<Map<String, dynamic>>? _locationSub;
  StreamSubscription<int>? _batterySub;

  bool get isTracking => _isTracking;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  int get batteryLevel => _batteryLevel;
  TrackingSession? get activeSession => _activeSession;
  List<LocationRecord> get records => List.unmodifiable(_records);

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _backgroundService.startListening();
    _locationSub = _backgroundService.locationStream.listen((_) {
      _loadFromNativeStore();
    });
    _batterySub = _batteryService.batteryStream.listen((level) {
      _batteryLevel = level;
      notifyListeners();
    });

    _batteryService.startPolling();
    _batteryLevel = await _batteryService.getBatteryLevel();

    await _restoreSessionState();
    await onAppResumed();

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  /// Called when app reopens — loads ALL locations from native SQLite.
  Future<void> onAppResumed() async {
    final nativeState = await _backgroundService.getTrackingState();
    _isTracking = nativeState.isActive;

    if (_isTracking && nativeState.sessionId != null) {
      _activeSession ??= await _sessionRepository.getActiveSession();
      if (_activeSession == null ||
          _activeSession!.id != nativeState.sessionId) {
        final session = TrackingSession(
          id: nativeState.sessionId!,
          startedAt: DateTime.now(),
          isActive: true,
        );
        await _sessionRepository.saveSession(session);
        _activeSession = session;
      }
    }

    await _loadFromNativeStore();
    notifyListeners();
  }

  Future<void> _restoreSessionState() async {
    _activeSession = await _sessionRepository.getActiveSession();
  }

  /// Native SQLite is the source of truth — always read from there.
  Future<void> _loadFromNativeStore() async {
    final sessionId = _activeSession?.id;
    if (sessionId == null) {
      _records = await _locationRepository.getAllRecords();
      notifyListeners();
      return;
    }

    final nativeList =
        await _backgroundService.getSessionLocations(sessionId);

    _records = nativeList.map(_mapToRecord).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Keep Hive in sync as backup.
    for (final record in _records) {
      await _locationRepository.saveRecord(record);
    }

    notifyListeners();
  }

  LocationRecord _mapToRecord(Map<String, dynamic> data) {
    final timestampRaw = data['timestamp'];
    final timestampMs = timestampRaw is int
        ? timestampRaw
        : (timestampRaw as num).toInt();

    return LocationRecord(
      id: data['id']?.toString() ?? _uuid.v4(),
      sessionId: data['sessionId']?.toString() ?? _activeSession?.id ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      accuracy: (data['accuracy'] as num).toDouble(),
    );
  }

  Future<void> startTracking() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    final granted = await _backgroundService.requestPermissions();
    if (!granted) {
      _errorMessage =
          'Location permission denied. Enable "Allow all the time" in Settings.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    await _backgroundService.requestBatteryOptimizationExemption();
    await _backgroundService.openAutostartSettings();
    await _backgroundService.openVivoBackgroundSettings();

    final session = TrackingSession(
      id: _uuid.v4(),
      startedAt: DateTime.now(),
      isActive: true,
    );
    await _sessionRepository.saveSession(session);
    _activeSession = session;

    final started = await _backgroundService.startTracking(
      sessionId: session.id,
    );
    if (!started) {
      _errorMessage = 'Failed to start background tracking service.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isTracking = true;
    _records = [];
    _isLoading = false;
    notifyListeners();

    // Load first point after short delay.
    await Future<void>.delayed(const Duration(seconds: 2));
    await _loadFromNativeStore();
  }

  Future<void> stopTracking() async {
    _isLoading = true;
    notifyListeners();

    await _backgroundService.stopTracking();
    await _loadFromNativeStore();

    if (_activeSession != null) {
      final stopped = _activeSession!.copyWith(
        stoppedAt: DateTime.now(),
        isActive: false,
      );
      await _sessionRepository.saveSession(stopped);
      await _sessionRepository.clearActiveSession();
      _activeSession = null;
    }

    _isTracking = false;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshRecords() async {
    await _loadFromNativeStore();
  }

  Future<LocationRecord?> getLatestForMap() async {
    if (_records.isNotEmpty) return _records.first;
    final position = await _locationService.getCurrentPosition();
    if (position == null) return null;
    return LocationRecord(
      id: _uuid.v4(),
      sessionId: _activeSession?.id ?? 'preview',
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      accuracy: position.accuracy,
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _batterySub?.cancel();
    _batteryService.dispose();
    _backgroundService.dispose();
    super.dispose();
  }
}
