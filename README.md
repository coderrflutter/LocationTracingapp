# Background Location Tracker

Production-ready Flutter app that tracks GPS every **60 seconds** in foreground, background, and when the screen is locked. Android uses a **Foreground Service** that survives task removal; iOS uses **background location** mode.

## Features

- START / STOP tracking with session persistence (Hive)
- Location records: latitude, longitude, timestamp, accuracy
- Battery percentage via **custom Platform Channels** (Kotlin + Swift)
- OpenStreetMap view of recorded points
- Clean architecture folder layout

## Project Structure

```
lib/
├── main.dart
├── app.dart
├── core/constants/app_constants.dart
├── domain/entities/          # LocationRecord, TrackingSession
├── domain/repositories/        # Repository interfaces
├── data/datasources/           # Hive implementation
├── services/                   # Battery, background tracking, location
└── presentation/
    ├── screens/                # Home + Map
    └── viewmodels/             # TrackingViewModel

android/.../kotlin/             # Foreground service, receivers, channels
ios/Runner/                     # CLLocationManager, channels
```

## Run

```bash
cd backround_location_tracking
flutter pub get
flutter run
```

### Android setup

1. Grant **Allow all the time** location permission when prompted.
2. Accept **Ignore battery optimizations** when prompted (required for reliable restart after force-kill).
3. Enable **Notifications** (Android 13+) for the foreground service notification.

### iOS setup

1. In Settings → Privacy → Location Services, set this app to **Always**.
2. Test on a **physical device** (simulator background location is limited).

## Platform Channels

| Channel | Methods |
|---------|---------|
| `.../tracking` | `startTracking`, `stopTracking`, `isTrackingActive`, `getBufferedLocations` |
| `.../battery` | `getBatteryLevel` |
| `.../location_events` | Event stream of GPS fixes |

## Notes

- **Force Stop** from Android Settings stops all background work until the user reopens the app (OS limitation).
- Swiping the app from recents is handled via `START_STICKY`, `AlarmManager`, and `BootReceiver`.
- Native code buffers locations when Flutter is not running; they sync into Hive on next launch.
