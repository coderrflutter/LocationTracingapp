import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/location_record.dart';
import '../viewmodels/tracking_view_model.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.viewModel});

  final TrackingViewModel viewModel;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.viewModel.addListener(_onViewModelChanged);
    widget.viewModel.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Skip the first resumed event — initialize() already syncs on cold start.
    if (state == AppLifecycleState.resumed &&
        widget.viewModel.isInitialized) {
      widget.viewModel.onAppResumed();
    }
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final dateFormat = DateFormat('MMM d, yyyy HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Location Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Map view',
            onPressed: vm.records.isEmpty && !vm.isTracking
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MapScreen(viewModel: vm),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: vm.isLoading && vm.records.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: vm.refreshRecords,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatusCard(viewModel: vm),
                  const SizedBox(height: 16),
                  _TrackingControls(viewModel: vm),
                  if (vm.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      vm.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Recorded Locations (${vm.records.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (vm.records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No locations yet.\nPress START to begin tracking.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...vm.records.map(
                      (LocationRecord record) => _LocationListTile(
                        record: record,
                        formattedTime: dateFormat.format(record.timestamp),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.viewModel});

  final TrackingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final batteryText = viewModel.batteryLevel >= 0
        ? '${viewModel.batteryLevel}%'
        : 'N/A';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  viewModel.isTracking
                      ? Icons.gps_fixed
                      : Icons.gps_off,
                  color: viewModel.isTracking ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  viewModel.isTracking ? 'Tracking Active' : 'Tracking Stopped',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoChip(
                  icon: Icons.battery_std,
                  label: 'Battery',
                  value: batteryText,
                ),
                _InfoChip(
                  icon: Icons.timer,
                  label: 'Interval',
                  value: '60s',
                ),
                _InfoChip(
                  icon: Icons.place,
                  label: 'Points',
                  value: '${viewModel.records.length}',
                ),
              ],
            ),
            if (viewModel.activeSession != null) ...[
              const SizedBox(height: 8),
              Text(
                'Session: ${viewModel.activeSession!.id.substring(0, 8)}...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _TrackingControls extends StatelessWidget {
  const _TrackingControls({required this.viewModel});

  final TrackingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: viewModel.isTracking || viewModel.isLoading
                ? null
                : viewModel.startTracking,
            icon: const Icon(Icons.play_arrow),
            label: const Text('START'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: !viewModel.isTracking || viewModel.isLoading
                ? null
                : viewModel.stopTracking,
            icon: const Icon(Icons.stop),
            label: const Text('STOP'),
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationListTile extends StatelessWidget {
  const _LocationListTile({
    required this.record,
    required this.formattedTime,
  });

  final LocationRecord record;
  final String formattedTime;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.location_on)),
        title: Text(
          '${record.latitude.toStringAsFixed(6)}, '
          '${record.longitude.toStringAsFixed(6)}',
        ),
        subtitle: Text(
          '$formattedTime\nAccuracy: ${record.accuracy.toStringAsFixed(1)} m',
        ),
        isThreeLine: true,
      ),
    );
  }
}
