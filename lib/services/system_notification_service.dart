import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class SystemNotificationService {
  static final SystemNotificationService _instance = SystemNotificationService._internal();
  factory SystemNotificationService() => _instance;
  SystemNotificationService._internal();

  bool _isInitialized = false;
  
  bool _isFirstClientBookingSnapshot = true;
  bool _isFirstProviderBookingSnapshot = true;
  bool _isFirstReviewSnapshot = true;
  
  final Map<String, String> _lastSeenBookingStatus = {};

  String? _currentUserUid;
  String? _currentUserRole;
  StreamSubscription<QuerySnapshot>? _clientBookingSub;
  StreamSubscription<QuerySnapshot>? _providerBookingSub;
  StreamSubscription<QuerySnapshot>? _providerReviewSub;

  void initialize({required String userRole}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_isInitialized && _currentUserUid == user.uid && _currentUserRole == userRole) return;
    
    _clientBookingSub?.cancel();
    _providerBookingSub?.cancel();
    _providerReviewSub?.cancel();

    _isInitialized = true;
    _currentUserUid = user.uid;
    _currentUserRole = userRole;

    if (userRole == 'client') {
      _listenToClientBookings(user.uid);
    } else if (userRole == 'provider') {
      _listenToProviderBookings(user.uid);
      _listenToProviderReviews(user.uid);
    }
  }

  void _showToast(String title, String subtitle, IconData icon, Color color) {
    showSimpleNotification(
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
      background: color,
      duration: const Duration(seconds: 4),
      leading: Icon(icon, color: Colors.white),
      slideDismissDirection: DismissDirection.up,
    );
  }

  void _listenToClientBookings(String uid) {
    _clientBookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('clientId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
          
      if (_isFirstClientBookingSnapshot) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          _lastSeenBookingStatus[doc.id] = data['status'] ?? 'pending';
        }
        _isFirstClientBookingSnapshot = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final bookingId = doc.id;
          final status = data['status'] ?? 'pending';
          final providerName = data['providerBusinessName'] ?? 'Provider';

          final previousStatus = _lastSeenBookingStatus[bookingId];
          
          if (previousStatus != null && previousStatus != status) {
            _lastSeenBookingStatus[bookingId] = status;
            
            if (status == 'accepted') {
               _showToast("Booking Accepted!", "$providerName has accepted your request.", Icons.check_circle, Colors.green);
            } else if (status == 'declined') {
               final bool wasPaid = data['deposit_paid'] == true;
               _showToast(
                 wasPaid ? "Booking Declined & Refunded" : "Booking Declined", 
                 "$providerName has declined your request.${wasPaid ? ' Your deposit has been refunded.' : ''}", 
                 Icons.cancel, Colors.red
               );
            } else if (status == 'finished') {
               _showToast("Job Finished", "$providerName finished the job. Please leave a review!", Icons.done_all, Colors.blue);
            }
          } else if (previousStatus == null) {
            _lastSeenBookingStatus[bookingId] = status;
          }
        }
      }
    });
  }

  void _listenToProviderBookings(String uid) {
    _providerBookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
          
      if (_isFirstProviderBookingSnapshot) {
        _isFirstProviderBookingSnapshot = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>? ?? {};
          final clientName = data['clientName'] ?? 'A client';
          final serviceType = data['serviceType'] ?? 'a service';
          
          _showToast(
            "New Booking Request", 
            "$clientName has requested $serviceType.", 
            Icons.event_available, 
            Colors.orange.shade800
          );
        }
      }
    });
  }

  void _listenToProviderReviews(String uid) {
    _providerReviewSub = FirebaseFirestore.instance
        .collection('service_providers')
        .doc(uid)
        .collection('reviews')
        .snapshots()
        .listen((snapshot) {
          
      if (_isFirstReviewSnapshot) {
        _isFirstReviewSnapshot = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>? ?? {};
          final ratingNum = data['rating'] ?? 5;
          
          _showToast(
            "New Review Received!", 
            "You just got a $ratingNum-star review.", 
            Icons.star, 
            Colors.amber.shade700
          );
        }
      }
    });
  }
}
