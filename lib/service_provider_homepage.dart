import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:handy_link/assets/service_provider_change_password.dart';
import 'package:handy_link/assets/rating_summary.dart';
import 'package:handy_link/assets/view_reviews.dart';
import 'package:handy_link/service_provider_profile_settings.dart';
import 'package:handy_link/provider_requests_page.dart';

/// The main landing dashboard for an authenticated service provider.
///
/// Displays the provider's business information from Firestore and provides 
/// navigation links to manage their profile, view/handle booking requests, 
/// and check their ratings and reviews.
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
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

  @override
  Widget build(BuildContext context) {
    final displayName =
        _businessName.isNotEmpty ? _businessName : 'Service Provider';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Provider Homepage'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
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
                            'Profile Management',
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
    );
  }
}

