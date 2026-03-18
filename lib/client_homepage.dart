import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_profile_settings.dart';
import 'client_booking_page.dart';
import 'client_view_bookings_page.dart';

class ClientHomepage extends StatefulWidget {
  const ClientHomepage({super.key});

  @override
  State<ClientHomepage> createState() => _ClientHomepageState();
}

class _ClientHomepageState extends State<ClientHomepage> {
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClientData();
  }

  Future<void> _loadClientData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _firstName = data['firstName'] ?? '';
          _lastName = data['lastName'] ?? '';
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
    final fullName = _firstName.isNotEmpty || _lastName.isNotEmpty
        ? '$_firstName $_lastName'.trim()
        : 'Client';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Homepage'),
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
                            backgroundColor:
                                Theme.of(context).colorScheme.secondaryContainer,
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
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
                                  'Client',
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

                  // My Bookings Panel
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'My Bookings',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.add),
                            title: const Text('Add Booking'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ClientBookingPage(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('View Bookings'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ClientViewBookingsPage(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.history),
                            title: const Text('Booking History'),
                            onTap: () {
                              // Navigate to booking history
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Account Panel
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Account',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: const Text('Edit Profile'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ClientProfileSettings(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.lock),
                            title: const Text('Change Password'),
                            onTap: () {
                              // Navigate to change password
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
