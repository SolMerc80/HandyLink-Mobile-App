import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:handy_link/image_upload_service.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  bool _isVerifying = false;

  final ImagePicker _picker = ImagePicker();

  String? _scannedName;
  String? _scannedId;
  String? _idImageUrl;
  String? _selfieImageUrl;
  bool _isUploadingId = false;
  bool _isUploadingSelfie = false;

  final ImageUploadService _uploadService = ImageUploadService();

  @override
  void initState() {
    super.initState();
    _restoreState();
    _retrieveLostData();
    _setupFieldListeners();
  }

  void _setupFieldListeners() {
    _nameController.addListener(() => _saveToPrefs('last_fullName', _nameController.text));
    _idController.addListener(() => _saveToPrefs('last_nationalId', _idController.text));
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nameController.text = prefs.getString('last_fullName') ?? '';
        _idController.text = prefs.getString('last_nationalId') ?? '';
        _idImageUrl = prefs.getString('last_idImageUrl');
        _selfieImageUrl = prefs.getString('last_selfieImageUrl');
      });
    }
  }

  Future<void> _saveToPrefs(String key, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value != null) {
      await prefs.setString(key, value);
    } else {
      await prefs.remove(key);
    }
  }

  Future<void> _retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) return;

    if (response.file != null) {
      final prefs = await SharedPreferences.getInstance();
      final bool? isSelfie = prefs.getBool('is_picking_selfie');
      
      if (isSelfie != null) {
        await _handlePickedFile(response.file!, isSelfie);
      }
    } else if (response.exception != null) {
      debugPrint('Lost data exception: ${response.exception!.message}');
    }
  }

  Future<void> _handlePickedFile(XFile image, bool isSelfie) async {
    setState(() {
      if (isSelfie) {
        _isUploadingSelfie = true;
      } else {
        _isUploadingId = true;
      }
    });

    try {
      final File imageFile = File(image.path);
      final String? uploadedUrl = await _uploadService.uploadImage(imageFile);

      if (uploadedUrl == null) {
        throw Exception('Failed to upload image. Please try again.');
      }

      setState(() {
        if (isSelfie) {
          _selfieImageUrl = uploadedUrl;
          _saveToPrefs('last_selfieImageUrl', uploadedUrl);
        } else {
          _idImageUrl = uploadedUrl;
          _saveToPrefs('last_idImageUrl', uploadedUrl);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isSelfie) {
            _isUploadingSelfie = false;
          } else {
            _isUploadingId = false;
          }
        });
      }
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source, bool isSelfie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_picking_selfie', isSelfie);

    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    await _handlePickedFile(image, isSelfie);
  }

  Future<void> _validateAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_idImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your National ID.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selfieImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a selfie for verification.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final enteredIdRaw = _idController.text.trim().toUpperCase();

      // Check if unique in Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('service_providers')
          .where('nationalId', isEqualTo: enteredIdRaw)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        for (var doc in querySnapshot.docs) {
          if (doc.id != currentUserId) {
             throw Exception('This National ID is already associated with another provider.');
          }
        }
      }

      _scannedName = _nameController.text.trim();
      _scannedId = enteredIdRaw;

      await _saveVerification();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _saveVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('service_providers')
            .doc(user.uid)
            .update({
          'verificationStatus': 'pending',
          if (_scannedName != null && _scannedName!.isNotEmpty) 'fullName': _scannedName,
          if (_scannedId != null && _scannedId!.isNotEmpty) 'nationalId': _scannedId,
          if (_idImageUrl != null && _idImageUrl!.isNotEmpty) 'idImageUrl': _idImageUrl,
          if (_selfieImageUrl != null && _selfieImageUrl!.isNotEmpty) 'selfieImageUrl': _selfieImageUrl,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification details submitted. Pending admin approval.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
        
        // Clear saved state after successful submission
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_fullName');
        await prefs.remove('last_nationalId');
        await prefs.remove('last_idImageUrl');
        await prefs.remove('last_selfieImageUrl');
        await prefs.remove('is_picking_selfie');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save to database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog(bool isSelfie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadImage(ImageSource.camera, isSelfie);
                    },
                  ),
                  _ImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadImage(ImageSource.gallery, isSelfie);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Verify Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2B5876), Color(0xFF4E4376)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1.5),
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            child: const Icon(
                              Icons.perm_identity_rounded,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Identity Verification',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Enter your exact details exactly as they appear on your National ID, then upload a clear image of the document. An administrator will review your submission.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon:
                                  const Icon(Icons.person, color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Colors.white30),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _idController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'National ID Number',
                              hintText: 'e.g. 70-2046601K40',
                              hintStyle: const TextStyle(color: Colors.white30),
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon:
                                  const Icon(Icons.badge, color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Colors.white30),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your National ID number.';
                              }
                              // Example format match (relaxed for letters/numbers):
                              final idRegex = RegExp(
                                  r'^\d{2}[-\s]?\d{6,7}[-\s]?[a-zA-Z][-\s]?\d{2}$');
                              if (!idRegex.hasMatch(value)) {
                                return 'Format invalid. Use pattern like: 70-2046601K40';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Required Documents',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildUploadCard(
                            title: 'National ID',
                            subtitle: 'Upload a clear photo of your ID',
                            imageUrl: _idImageUrl,
                            isUploading: _isUploadingId,
                            onTap: () => _showImageSourceDialog(false),
                            icon: Icons.badge,
                          ),
                          const SizedBox(height: 16),
                          _buildUploadCard(
                            title: 'Selfie',
                            subtitle: 'Upload a clear selfie photo',
                            imageUrl: _selfieImageUrl,
                            isUploading: _isUploadingSelfie,
                            onTap: () => _showImageSourceDialog(true),
                            icon: Icons.face,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isVerifying
                                  ? null
                                  : _validateAndSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF2B5876),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                              ),
                              icon: _isVerifying
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle),
                              label: const Text(
                                'Submit for Verification',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required String? imageUrl,
    required bool isUploading,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: imageUrl != null ? Colors.green.withOpacity(0.5) : Colors.white24,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: imageUrl != null ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                imageUrl != null ? Icons.check : icon,
                color: imageUrl != null ? Colors.green : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    imageUrl != null ? 'Image uploaded' : subtitle,
                    style: TextStyle(
                      color: imageUrl != null ? Colors.green : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isUploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  imageUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFF2B5876)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
