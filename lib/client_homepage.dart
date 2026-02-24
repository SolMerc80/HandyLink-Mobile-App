import 'package:flutter/material.dart';
import 'client_profile_settings.dart';

class ClientHomepage extends StatelessWidget {
  const ClientHomepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Homepage'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Header
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24.0,
                  horizontal: 135.0,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Jane Doe',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Client',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
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
                    const Text('My Bookings', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('View Bookings'),
                      onTap: () {
                        // Navigate to view bookings
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
                    const Text('Account', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Edit Profile'),
                      onTap: () {
                        // Navigate to edit profile
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
