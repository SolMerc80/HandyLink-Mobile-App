/*import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

class ServiceProviderProfileSettings extends StatefulWidget {
  const ServiceProviderProfileSettings({super.key});

  @override
  _ServiceProviderProfileSettingsState createState() => _ServiceProviderProfileSettingsState();
}

class _ServiceProviderProfileSettingsState extends State<ServiceProviderProfileSettings> {
  File? _image;
  final picker = ImagePicker();

  final TextEditingController _usernameController = TextEditingController(text: 'username');
  final TextEditingController _emailController = TextEditingController(text: 'johndoe@example.com');
  final TextEditingController _phoneController = TextEditingController(text: '+263 77 123 4567');
  final TextEditingController _serviceController = TextEditingController(text: 'Painter');

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(()
      _image = File(pickedFile.path);
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile Settings'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _image != null
                  ? FileImage(_image!)
                  : AssetImage(lib\assets\images\PHOTO-2026-01-05-17-10-37.jpg) as ImageProvider,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.camera_alt, color: Colors.white70),
                ),
              ),
            ),
            SizedBox(height: 16),

            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),

            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Phone'),
            ),

            TextField(
              controller: _serviceController,
              decoration: InputDecoration(labelText: 'Service'),
            ),
            SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                //Save Logic
              },
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}*/

  import 'package:flutter/material.dart';

  class ServiceProviderProfileSettings extends StatelessWidget {
  final String profileImage = 'lib\assets\images\PHOTO-2026-01-05-17-10-37.jpg';
  final String email = 'johndoe@example.com';
  final String phone = '+263 77 123 4567';
  final String service = 'Painter';
  
  const ServiceProviderProfileSettings ({super.key});

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Profile Settings'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: AssetImage('lib/assets/images/PHOTO-2026-01-05-17-10-37.jpg'),
              ),
              SizedBox(height: 16),
              Text(
                'username',
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
              ListTile(
                leading: Icon(Icons.work),
                title: Text(service),
              ),
            ],
          ),
        ),
      );
    }
  }
