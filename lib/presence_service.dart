import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService extends WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    // Initial set
    _updatePresence(true);
    _isInitialized = true;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updatePresence(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _updatePresence(false);
    }
  }

  Future<void> _updatePresence(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = {
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    };

    try {
      FirebaseFirestore.instance.collection('clients').doc(user.uid).set(data, SetOptions(merge: true));
      FirebaseFirestore.instance.collection('service_providers').doc(user.uid).set(data, SetOptions(merge: true));
    } catch (_) {}
  }
}
