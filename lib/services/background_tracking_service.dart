import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/app_constants.dart';

class BackgroundTrackingService {
  BackgroundTrackingService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ??
            const MethodChannel(AppConstants.trackingMethodChannel),
        _eventChannel = eventChannel ??
            const EventChannel(AppConstants.locationEventChannel);

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  StreamSubscription<dynamic>? _locationSubscription;
  final StreamController<Map<String, dynamic>> _locationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get locationStream => _locationController.stream;

  Future<bool> requestPermissions() async {
    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) return false;

    if (await Permission.locationAlways.isDenied) {
      final alwaysStatus = await Permission.locationAlways.request();
      if (!alwaysStatus.isGranted) return false;
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    return true;
  }

  Future<void> requestBatteryOptimizationExemption() async {
    try {
      await _methodChannel.invokeMethod<void>(
        'requestBatteryOptimizationExemption',
      );
    } on PlatformException {
      return;
    }
  }

  Future<void> openAutostartSettings() async {
    try {
      await _methodChannel.invokeMethod<void>('openAutostartSettings');
    } on PlatformException {
      return;
    }
  }

  Future<void> openVivoBackgroundSettings() async {
    try {
      await _methodChannel.invokeMethod<void>('openVivoBackgroundSettings');
    } on PlatformException {
      return;
    }
  }

  Future<bool> startTracking({required String sessionId}) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'startTracking',
        {
          'sessionId': sessionId,
          'intervalSeconds': AppConstants.locationIntervalSeconds,
        },
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> stopTracking() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('stopTracking');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isTrackingActive() async {
    final state = await getTrackingState();
    return state.isActive;
  }

  Future<NativeTrackingState> getTrackingState() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getTrackingState',
      );
      if (result == null) return const NativeTrackingState(isActive: false);
      return NativeTrackingState(
        isActive: result['isActive'] as bool? ?? false,
        sessionId: result['sessionId'] as String?,
        serviceRunning: result['serviceRunning'] as bool? ?? false,
      );
    } on PlatformException {
      return const NativeTrackingState(isActive: false);
    }
  }

  Future<List<Map<String, dynamic>>> getSessionLocations(
    String sessionId,
  ) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getSessionLocations',
        {'sessionId': sessionId},
      );
      if (result == null) return [];
      return result
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on PlatformException {
      return [];
    }
  }

  void startListening() {
    _locationSubscription?.cancel();
    _locationSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen((event) {
      if (event is Map) {
        _locationController.add(Map<String, dynamic>.from(event));
      }
    });
  }

  void stopListening() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void dispose() {
    stopListening();
    _locationController.close();
  }
}

class NativeTrackingState {
  const NativeTrackingState({
    required this.isActive,
    this.sessionId,
    this.serviceRunning = false,
  });

  final bool isActive;
  final String? sessionId;
  final bool serviceRunning;
}

class LocationService {
  Future<Position?> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}
