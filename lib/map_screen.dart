import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_service.dart';
import 'firestore_service.dart';

class MapScreen extends StatefulWidget {
  final String userRole; // 'client' or 'provider'
  final String? targetId; // If there's a specific booking in progress
  final LatLng? targetLocation; // Route coordinate

  const MapScreen({
    super.key,
    required this.userRole,
    this.targetId,
    this.targetLocation,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  GoogleMapController? _mapController;
  
  Set<Marker> _markers = {};
  LatLng? _currentLatLng;
  LatLng? _targetLatLng;
  List<LatLng> _routePoints = [];
  LatLng? _lastFetchedRouteTarget;

  @override
  void initState() {
    super.initState();
    _currentLatLng = _getLoc();
  }

  LatLng? _getLoc() {
    final pos = LocationService().currentPosition;
    if (pos == null) return null;
    return LatLng(pos.latitude, pos.longitude);
  }

  Set<Marker> _getMarkersFromDocs(List<QueryDocumentSnapshot> docs) {
    if (currentUser == null) return {};
    
    Set<Marker> newMarkers = {};
    
    // Add explicitly known current position marker
    if (_currentLatLng != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'My Location'),
        )
      );
    }
    
    // Remote users
    for (var doc in docs) {
      if (doc.id == currentUser!.uid) continue; // skip self if fetched
      
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['latitude'];
      final lng = data['longitude'];
      
      String name = data['businessName'] ?? data['firstName'] ?? data['name'] ?? 'User';
      if (name.trim().isEmpty) name = 'User';
      
      if (lat != null && lng != null) {
        final pos = LatLng(lat, lng);
        final isTarget = doc.id == widget.targetId;
        
        if (isTarget && _targetLatLng != pos) {
          // This is a bit of a side effect, but needed for route fetching
          Future.microtask(() {
            if (mounted) {
              setState(() {
                _targetLatLng = pos;
              });
              _checkAndFetchRoute();
            }
          });
        }
        
        newMarkers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: pos,
            onTap: () => _showUserDialog(doc.id, name, data['role'] ?? 'User'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isTarget ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: name,
              snippet: data['role'] ?? 'User',
            ),
          )
        );
      }
    }
    return newMarkers;
  }

  Future<void> _checkAndFetchRoute() async {
    if (_currentLatLng == null || _targetLatLng == null) return;
    
    if (_lastFetchedRouteTarget != null) {
      final dist = LocationService().calculateDistance(
        _lastFetchedRouteTarget!.latitude,
        _lastFetchedRouteTarget!.longitude,
        _targetLatLng!.latitude,
        _targetLatLng!.longitude,
      );
      // Fetch new route if target moved more than 20 meters
      if (dist < 20) return;
    }
    
    _lastFetchedRouteTarget = _targetLatLng;
    
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_currentLatLng!.longitude},${_currentLatLng!.latitude};'
        '${_targetLatLng!.longitude},${_targetLatLng!.latitude}?geometries=geojson'
      );
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          setState(() {
            _routePoints = coordinates
                .map((coord) => LatLng(coord[1] as double, coord[0] as double))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    }
  }

  void _showUserDialog(String targetUid, String targetName, String targetRole) {
    if (currentUser == null) return;
    
    // Find the position for this user in the latest markers or docs
    // For simplicity, we can fetch it from the latest targetLatLng if it matches
    // but better to just look it up if we have the docs.
    // For now, if it's the target user, we use _targetLatLng.
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(targetName),
        content: Text('This user is a $targetRole.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_targetLatLng != null && targetUid == widget.targetId) {
                _launchNavigation(_targetLatLng!.latitude, _targetLatLng!.longitude);
              } else {
                // If it's another user, we don't have their Pos easily here without passing it
                // but usually the target is who we want to navigate to.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigation only available for target booking user'))
                );
              }
            },
            child: const Text('Navigate'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      )
    );
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    final googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng');
    final appleMapsUrl = Uri.parse('maps://?q=$lat,$lng');

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl);
      } else {
        final webUrl = Uri.parse('https://maps.apple.com/?q=$lat,$lng');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } else {
      final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLatLng == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Map View')),
        body: const Center(child: Text('Requesting Location... Ensure GPS is on.')),
      );
    }
    
    final oppositeStream = widget.userRole == 'client' 
        ? FirestoreLocationService().streamProvidersLocations()
        : FirestoreLocationService().streamClientsLocations();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map Tracker'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentLatLng != null && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLatLng!, 15.0),
                );
              }
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: oppositeStream,
        builder: (context, snapshot) {
          final markers = snapshot.hasData 
              ? _getMarkersFromDocs(snapshot.data!.docs) 
              : <Marker>{};

          return GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: _currentLatLng!,
              zoom: 14.0,
            ),
            markers: markers,
            polylines: _routePoints.isNotEmpty
                ? {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: _routePoints,
                      color: Colors.blue.withOpacity(0.7),
                      width: 5,
                    ),
                  }
                : (widget.targetLocation != null
                    ? {
                        Polyline(
                          polylineId: const PolylineId('direct'),
                          points: [_currentLatLng!, widget.targetLocation!],
                          color: Colors.blue.withOpacity(0.7),
                          width: 5,
                        ),
                      }
                    : {}),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          );
        },
      ),
    );
  }
}
