import 'package:flutter/material.dart';

class ClientProfileSettings extends StatelessWidget {
  final String email = 'janedoe@example.com';
  final String phone = '+263 77 234 7895';

  const ClientProfileSettings ({super.key});

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text('profile Settings'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,

        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircleAvatar(
                radius: 60,
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
              const SizedBox(height: 16),
              Text(
                'Jane Doe',
                style: TextStyle(fontSize: 24,
                fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.email),
                title: Text(email),
              ),
              ListTile(
                leading: Icon(Icons.phone),
                title: Text(phone),
              ),
            ],
          ),
        ),
      );
    }
}