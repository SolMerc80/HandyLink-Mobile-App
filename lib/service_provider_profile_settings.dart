import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'verify_screen.dart';
import 'location_picker_screen.dart';
import 'image_upload_service.dart';

class ServiceProviderProfileSettings extends StatefulWidget {
  const ServiceProviderProfileSettings({super.key});

  @override
  State<ServiceProviderProfileSettings> createState() =>
      _ServiceProviderProfileSettingsState();
}

class _ServiceProviderProfileSettingsState
    extends State<ServiceProviderProfileSettings> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Service type dropdown
  String? _selectedServiceType;
  final List<String> _serviceTypes = [
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Cleaning',
    'Painting',
    'Gardening',
    'Other',
  ];

  bool _isVerified = false;
  String _verificationStatus = '';
  bool _isLoading = true;
  bool _isSaving = false;
  LatLng? _savedLocation;
  String? _profileImageUrl;
  bool _isUploading = false;
  double _walletBalance = 0.0;

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
          _businessNameController.text = data['businessName'] ?? '';
          _emailController.text = data['email'] ?? user.email ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _selectedServiceType = data['serviceType'];
          _isVerified = data['isVerified'] ?? false;
          _verificationStatus = data['verificationStatus'] ?? '';
          _profileImageUrl = data['profileImageUrl'];
          if (data['latitude'] != null && data['longitude'] != null) {
            _savedLocation = LatLng(data['latitude'], data['longitude']);
          }
          _walletBalance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProfilePicture() async {
    final imageFile = await ImageUploadService().pickImage();
    if (imageFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final url = await ImageUploadService().uploadImage(imageFile);
      if (url != null) {
        setState(() {
          _profileImageUrl = url;
        });
        
        // Auto-save the image URL to Firestore immediately
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('service_providers')
              .doc(user.uid)
              .update({'profileImageUrl': url});
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _pickLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(initialLocation: _savedLocation),
      ),
    );

    if (result != null) {
      setState(() {
        _savedLocation = result;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      Map<String, dynamic> updateData = {
        'businessName': _businessNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'serviceType': _selectedServiceType,
      };

      if (_savedLocation != null) {
        updateData['latitude'] = _savedLocation!.latitude;
        updateData['longitude'] = _savedLocation!.longitude;
      }

      await FirebaseFirestore.instance
          .collection('service_providers')
          .doc(user.uid)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showWithdrawalDialog() {
    final _amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Withdraw Funds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Available Balance: \$${_walletBalance.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount to Withdraw (\$)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                double? amount = double.tryParse(_amountController.text);
                if (amount == null || amount <= 0 || amount > _walletBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount'), backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(context);
                
                setState(() => _isLoading = true);
                try {
                  final user = FirebaseAuth.instance.currentUser!;
                  // Log the withdrawal request
                  await FirebaseFirestore.instance.collection('withdrawals').add({
                    'providerId': user.uid,
                    'amount': amount,
                    'status': 'pending',
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  // Safely deduct wallet balance
                  await FirebaseFirestore.instance.collection('service_providers').doc(user.uid).update({
                    'walletBalance': FieldValue.increment(-amount),
                  });
                  
                  await _loadProviderData();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal request submitted!'), backgroundColor: Colors.green));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Confirm Withdrawal'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar header with pick image functionality
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            backgroundImage: _profileImageUrl != null 
                                ? NetworkImage(_profileImageUrl!) 
                                : null,
                            child: _profileImageUrl == null
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  )
                                : null,
                          ),
                          if (_isUploading)
                            const Positioned.fill(
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              radius: 20,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                                onPressed: _isUploading ? null : _updateProfilePicture,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Verification Status
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isVerified
                            ? Colors.green.withOpacity(0.1)
                            : (_verificationStatus == 'pending'
                                ? Colors.orange.withOpacity(0.1)
                                : Theme.of(context).colorScheme.errorContainer.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isVerified
                              ? Colors.green
                              : (_verificationStatus == 'pending'
                                  ? Colors.orange
                                  : Theme.of(context).colorScheme.error),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isVerified
                                ? Icons.verified
                                : (_verificationStatus == 'pending'
                                    ? Icons.pending_actions
                                    : Icons.warning_amber_rounded),
                            color: _isVerified
                                ? Colors.green
                                : (_verificationStatus == 'pending'
                                    ? Colors.orange
                                    : Theme.of(context).colorScheme.error),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isVerified
                                      ? 'Profile Verified'
                                      : (_verificationStatus == 'pending'
                                          ? 'Verification Pending'
                                          : 'Profile Not Verified'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isVerified
                                        ? Colors.green.shade700
                                        : (_verificationStatus == 'pending'
                                            ? Colors.orange.shade800
                                            : Theme.of(context).colorScheme.error),
                                  ),
                                ),
                                if (!_isVerified && _verificationStatus != 'pending')
                                  Text(
                                    'Verify your profile to gain more trust.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                if (_verificationStatus == 'pending')
                                  Text(
                                    'Your submission is being reviewed by an admin.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!_isVerified && _verificationStatus != 'pending')
                            ElevatedButton(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const VerifyScreen(),
                                  ),
                                );
                                if (result == true) {
                                  _loadProviderData();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                                foregroundColor: Theme.of(context).colorScheme.onError,
                              ),
                              child: const Text('Verify'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // WALLET UI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Wallet Balance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              const SizedBox(height: 4),
                              Text('\$${_walletBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _walletBalance > 0 ? () => _showWithdrawalDialog() : null,
                            icon: const Icon(Icons.money),
                            label: const Text('Withdraw'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Profile Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Business Name
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Business Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your business name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email — read-only since it's the auth email
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.email),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.4),
                        helperText: 'Email cannot be changed here',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Service Type dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedServiceType,
                      decoration: const InputDecoration(
                        labelText: 'Service Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work),
                      ),
                      items: _serviceTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedServiceType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a service type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Location Picker Section
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on, color: Colors.red),
                      title: const Text('Business Location'),
                      subtitle: Text(_savedLocation != null 
                        ? 'Location saved: ${_savedLocation!.latitude.toStringAsFixed(4)}, ${_savedLocation!.longitude.toStringAsFixed(4)}' 
                        : 'No location set'),
                      trailing: ElevatedButton(
                        onPressed: _pickLocation,
                        child: Text(_savedLocation == null ? 'Set Location' : 'Update'),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 18,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
