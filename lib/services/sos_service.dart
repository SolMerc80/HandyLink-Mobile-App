import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class SOSService {
  static Future<void> triggerSOS(BuildContext context, String role) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError(context, 'User not logged in.');
        return;
      }

      final collection = role == 'client' ? 'clients' : 'service_providers';
      final doc = await FirebaseFirestore.instance.collection(collection).doc(user.uid).get();

      if (!doc.exists) {
        _showError(context, 'Profile data not found.');
        return;
      }

      final String? contact = doc.data()?['sosContact'];

      if (contact == null || contact.trim().isEmpty) {
        _showError(context, 'No SOS contact saved. Please add one in your profile settings.');
        return;
      }

      final Uri dialUri = Uri(scheme: 'tel', path: contact.trim());

      if (await canLaunchUrl(dialUri)) {
        await launchUrl(dialUri);
      } else {
        _showError(context, 'Could not launch dialer for $contact');
      }
    } catch (e) {
      _showError(context, 'SOS Error: $e');
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
