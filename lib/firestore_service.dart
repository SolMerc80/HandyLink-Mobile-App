import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class FirestoreLocationService {
  static final FirestoreLocationService _instance = FirestoreLocationService._internal();
  factory FirestoreLocationService() => _instance;
  FirestoreLocationService._internal();

  /// Updates current user's location to the specified collection (clients or service_providers)
  Future<void> updateLocation(String role, String uid, Position position) async {
    final collection = role == 'client' ? 'clients' : 'service_providers';
    
    await FirebaseFirestore.instance.collection(collection).doc(uid).set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'lastLocationUpdate': FieldValue.serverTimestamp(),
      'role': role, // to be safe
    }, SetOptions(merge: true));
  }

  /// Stream all clients with active locations
  Stream<QuerySnapshot> streamClientsLocations() {
    return FirebaseFirestore.instance
        .collection('clients')
        .where('latitude', isNull: false)
        .snapshots();
  }

  /// Stream all service providers with active locations
  Stream<QuerySnapshot> streamProvidersLocations() {
    return FirebaseFirestore.instance
        .collection('service_providers')
        .where('latitude', isNull: false)
        .snapshots();
  }
}
