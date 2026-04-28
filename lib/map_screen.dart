import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final MapController _mapController = MapController();
  
  List<Marker> _markers = [];
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

  void _buildMarkers(List<QueryDocumentSnapshot> docs) {
    if (currentUser == null) return;
    
    List<Marker> newMarkers = [];
    
    // Add explicitly known current position marker
    if (_currentLatLng != null) {
      newMarkers.add(
        Marker(
          point: _currentLatLng!,
          width: 50,
          height: 50,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
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
      final displayName = name.split(' ')[0];
      
      if (lat != null && lng != null) {
        final pos = LatLng(lat, lng);
        final isTarget = doc.id == widget.targetId;
        
        if (isTarget) {
          _targetLatLng = pos;
          _checkAndFetchRoute();
        }
        
        newMarkers.add(
          Marker(
            point: pos,
            width: 100,
            height: 80,
            child: GestureDetector(
              onTap: () => _showUserDialog(doc.id, name, data['role'] ?? 'User'),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    color: Colors.white70,
                    child: Text(
                      displayName, 
                      style: const TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.location_on, 
                    color: isTarget ? Colors.amber : Colors.red, 
                    size: isTarget ? 50 : 40,
                  ),
                ],
              ),
            ),
          )
        );
      }
    }
    
    setState(() {
      _markers = newMarkers;
    });
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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(targetName),
        content: Text('This user is a $targetRole.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      )
    );
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
              if (_currentLatLng != null) {
                _mapController.move(_currentLatLng!, 15.0);
              }
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: oppositeStream,
        builder: (context, snapshot) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (snapshot.hasData) {
              _buildMarkers(snapshot.data!.docs);
            }
          });

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLatLng!,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.handy_link',
              ),
              PolylineLayer(
                polylines: _routePoints.isNotEmpty
                    ? <Polyline<Object>>[
                        Polyline<Object>(
                          points: _routePoints,
                          color: Colors.blue.withOpacity(0.7),
                          strokeWidth: 5.0,
                        ),
                      ]
                    : ((_currentLatLng != null && widget.targetLocation != null)
                        ? <Polyline<Object>>[
                            Polyline<Object>(
                              points: [_currentLatLng!, widget.targetLocation!],
                              color: Colors.blue.withOpacity(0.7),
                              strokeWidth: 5.0,
                            ),
                          ]
                        : <Polyline<Object>>[]),
              ),
              MarkerLayer(markers: _markers),
            ],
          );
        },
      ),
    );
  }
}
