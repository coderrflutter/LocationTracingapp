import 'dart:async';

import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';

class BatteryService {
  BatteryService({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel(AppConstants.batteryMethodChannel);

  final MethodChannel _channel;
  Timer? _pollTimer;
  final StreamController<int> _batteryController =
      StreamController<int>.broadcast();

  Stream<int> get batteryStream => _batteryController.stream;

  Future<int> getBatteryLevel() async {
    try {
      final level = await _channel.invokeMethod<int>('getBatteryLevel');
      return level ?? -1;
    } on PlatformException {
      return -1;
    }
  }

  void startPolling({Duration interval = AppConstants.batteryPollInterval}) {
    _pollTimer?.cancel();
    unawaited(_emitBatteryLevel());
    _pollTimer = Timer.periodic(interval, (_) => _emitBatteryLevel());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _emitBatteryLevel() async {
    final level = await getBatteryLevel();
    if (!_batteryController.isClosed && level >= 0) {
      _batteryController.add(level);
    }
  }

  void dispose() {
    stopPolling();
    _batteryController.close();
  }
}
