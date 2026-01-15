import 'package:flutter/material.dart';
import 'package:handy_link/service_provider_profile_settings.dart';


class ServiceProviderHomepage extends StatelessWidget {
  const ServiceProviderHomepage ({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Provider Homepage'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      // backgroundColor: Colors.white, // allow theme to control background
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Management Panel
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text("Profile Management", style: TextStyle(fontSize: 18,)),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Edit profile'),
                      onTap: () {
                        // Navigate to edit profile

                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ServiceProviderProfileSettings(),
                        )
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

            const SizedBox(height: 16),
            // Reviews and Rating panel
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Reviews and Ratings', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.star),
                      title: const Text('View Reviews'),
                      onTap: () {
                        // Navigate to reviews screen
                      },
                    ),
                    
                    ListTile(
                      leading: const Icon(Icons.rate_review),
                      title: const Text('Rating Summary'),
                      onTap: () {
                        // Navigate to rating summary
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

