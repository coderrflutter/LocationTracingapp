import 'package:flutter/material.dart';

import 'data/datasources/location_hive_datasource.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/viewmodels/tracking_view_model.dart';
import 'services/background_tracking_service.dart';
import 'services/battery_service.dart';

/// Application root with dependency wiring.
class LocationTrackerApp extends StatelessWidget {
  const LocationTrackerApp({
    super.key,
    required this.viewModel,
  });

  final TrackingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Location Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HomeScreen(viewModel: viewModel),
    );
  }
}

/// Builds repositories and services, then launches the app.
Future<TrackingViewModel> bootstrap() async {
  final dataSource = await initHiveDataSource();
  final locationRepository = LocationRepositoryImpl(dataSource);
  final sessionRepository = TrackingSessionRepositoryImpl(dataSource);

  return TrackingViewModel(
    locationRepository: locationRepository,
    sessionRepository: sessionRepository,
    backgroundService: BackgroundTrackingService(),
    batteryService: BatteryService(),
    locationService: LocationService(),
  );
}
