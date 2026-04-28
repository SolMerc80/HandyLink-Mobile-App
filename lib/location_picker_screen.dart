import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _selectedLatLng;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedLatLng = widget.initialLocation ?? _getInitialLocation();
  }

  LatLng? _getInitialLocation() {
    final pos = LocationService().currentPosition;
    if (pos != null) return LatLng(pos.latitude, pos.longitude);
    return const LatLng(0, 0); // Default to center of world if nothing else
  }

  void _handleTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          if (_selectedLatLng != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _selectedLatLng),
              child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _selectedLatLng ?? const LatLng(0, 0),
          initialZoom: 15.0,
          onTap: _handleTap,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.handy_link',
          ),
          if (_selectedLatLng != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedLatLng!,
                  width: 80,
                  height: 80,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final pos = LocationService().currentPosition;
          if (pos != null) {
            final current = LatLng(pos.latitude, pos.longitude);
            _mapController.move(current, 15.0);
            setState(() {
              _selectedLatLng = current;
            });
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
