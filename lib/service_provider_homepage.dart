import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:handy_link/assets/service_provider_change_password.dart';
import 'package:handy_link/assets/rating_summary.dart';
import 'package:handy_link/assets/view_reviews.dart';
import 'package:handy_link/service_provider_profile_settings.dart';
import 'package:handy_link/provider_requests_page.dart';
import 'presence_service.dart';
import 'location_service.dart';
import 'firestore_service.dart';
import 'map_screen.dart';
import 'package:handy_link/services/system_notification_service.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';

class ServiceProviderHomepage extends StatefulWidget {
  const ServiceProviderHomepage({super.key});

  @override
  State<ServiceProviderHomepage> createState() =>
      _ServiceProviderHomepageState();
}

class _ServiceProviderHomepageState extends State<ServiceProviderHomepage> {
  String _businessName = '';
  String _serviceType = '';
  String _email = '';
  String? _profileImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    PresenceService().initialize();
    SystemNotificationService().initialize(userRole: 'provider');
    _initLocationTracking();
    _loadProviderData();
  }

  Future<void> _initLocationTracking() async {
    final hasPermission = await LocationService().requestPermissions();
    if (hasPermission) {
      LocationService().onLocationUpdated = (position) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          FirestoreLocationService().updateLocation('provider', user.uid, position);
        }
      };
      LocationService().startTracking();
    }
  }

  @override
  void dispose() {
    PresenceService().dispose();
    super.dispose();
  }

  Future<void> _loadProviderData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _businessName = data['businessName'] ?? '';
          _serviceType = data['serviceType'] ?? '';
          _email = data['email'] ?? user.email ?? '';
          _profileImageUrl = data['profileImageUrl'];
        });
      }
    } catch (e) {
      // Silently fail — fields remain empty
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _showReportDialog(String displayName) {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Report an Issue'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'e.g. Technical bug, Client issue',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  if (subjectController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }

                  setState(() => isSubmitting = true);

                  try {
                    await FirebaseFirestore.instance.collection('reports').add({
                      'reporterName': displayName,
                      'reporterId': FirebaseAuth.instance.currentUser?.uid,
                      'role': 'provider',
                      'subject': subjectController.text.trim(),
                      'message': messageController.text.trim(),
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report submitted successfully. Admin will review it.'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    setState(() => isSubmitting = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text('Submit Report'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        _businessName.isNotEmpty ? _businessName : 'Service Provider';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit System'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('OK'),
              ),
            ],
          ),
        ) ?? false;
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Service Provider Homepage'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MapScreen(userRole: 'provider'),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24.0,
                        horizontal: 40.0,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            backgroundImage: _profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!)
                                : null,
                            child: _profileImageUrl == null
                                ? Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _email,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _serviceType.isNotEmpty
                                      ? _serviceType
                                      : 'Service Provider',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Profile Management Panel
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Profile & Support',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: const Text('Edit profile'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ServiceProviderProfileSettings(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.lock),
                            title: const Text('Change Password'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ServiceProviderChangePassword(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.report_problem, color: Colors.orange),
                            title: const Text('Report an Issue'),
                            onTap: () => _showReportDialog(displayName),
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout, color: Colors.red),
                            title: const Text('Logout', style: TextStyle(color: Colors.red)),
                            onTap: () => _showLogoutConfirmation(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bookings & Requests Panel
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Bookings & Requests',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.inbox),
                            title: const Text('View Requests'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ServiceProviderRequestsPage(),
                                ),
                              );
                            },
                          ),

                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Reviews and Rating panel
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Reviews and Ratings',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.star),
                            title: const Text('View Reviews'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ViewReviewsPage(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.rate_review),
                            title: const Text('Rating Summary'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RatingSummaryPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
