class AppConstants {
  AppConstants._();

  static const String trackingMethodChannel =
      'com.example.backround_location_tracking/tracking';
  static const String batteryMethodChannel =
      'com.example.backround_location_tracking/battery';
  static const String locationEventChannel =
      'com.example.backround_location_tracking/location_events';

  static const String hiveBoxName = 'location_records';
  static const String hiveSessionBoxName = 'tracking_sessions';
  static const String hiveSettingsBoxName = 'app_settings';

  static const int locationIntervalSeconds = 60;

  static const Duration batteryPollInterval = Duration(seconds: 30);
}
