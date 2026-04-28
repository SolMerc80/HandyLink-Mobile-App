import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _selectedLatLng;
  GoogleMapController? _mapController;

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

  void _handleTap(LatLng latLng) {
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
      body: GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        initialCameraPosition: CameraPosition(
          target: _selectedLatLng ?? const LatLng(0, 0),
          zoom: 15.0,
        ),
        onTap: _handleTap,
        markers: _selectedLatLng != null
            ? {
                Marker(
                  markerId: const MarkerId('picked_location'),
                  position: _selectedLatLng!,
                ),
              }
            : {},
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final pos = LocationService().currentPosition;
          if (pos != null) {
            final current = LatLng(pos.latitude, pos.longitude);
            _mapController?.animateCamera(CameraUpdate.newLatLng(current));
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
