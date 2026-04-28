import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  
  // Expose stream or current position
  Position? get currentPosition => _currentPosition;
  
  // Callback when location updates natively
  Function(Position)? onLocationUpdated;

  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) print('Location services are disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) print('Location permissions are denied');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) print('Location permissions are permanently denied.');
      return false;
    }
    
    return true;
  }

  void startTracking() {
    // Already tracking?
    if (_positionStream != null) return;

    // Optimize battery usage
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Only trigger stream if moved 10 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      _currentPosition = position;
      if (onLocationUpdated != null) {
        onLocationUpdated!(position);
      }
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  // Haversine Distance (returns distance in meters)
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
