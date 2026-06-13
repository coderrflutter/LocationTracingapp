import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/location_record.dart';
import '../viewmodels/tracking_view_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.viewModel});

  final TrackingViewModel viewModel;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _center;

  @override
  void initState() {
    super.initState();
    _resolveCenter();
  }

  Future<void> _resolveCenter() async {
    final records = widget.viewModel.records;
    if (records.isNotEmpty) {
      setState(() {
        _center = LatLng(records.first.latitude, records.first.longitude);
      });
      return;
    }
    final latest = await widget.viewModel.getLatestForMap();
    if (latest != null && mounted) {
      setState(() {
        _center = LatLng(latest.latitude, latest.longitude);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.viewModel.records;
    final center = _center ?? const LatLng(0, 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Location Map')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: records.length <= 1 ? 15 : 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.backround_location_tracking',
          ),
          if (records.isNotEmpty)
            MarkerLayer(
              markers: [
                for (var i = 0; i < records.length; i++)
                  Marker(
                    point: LatLng(
                      records[i].latitude,
                      records[i].longitude,
                    ),
                    width: 36,
                    height: 36,
                    child: Icon(
                      i == 0 ? Icons.location_on : Icons.circle,
                      color: i == 0 ? Colors.red : Colors.blue,
                      size: i == 0 ? 36 : 12,
                    ),
                  ),
              ],
            ),
          if (records.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: records
                      .map((LocationRecord r) => LatLng(r.latitude, r.longitude))
                      .toList(),
                  strokeWidth: 3,
                  color: Colors.blue,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
