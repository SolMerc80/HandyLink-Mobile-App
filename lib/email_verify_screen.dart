import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:handy_link/services/brevo_service.dart';
import 'dart:math';

class EmailVerifyScreen extends StatefulWidget {
  final String email;
  final String name;
  final String role; // 'client' or 'provider'
  final Map<String, dynamic>? userData; // Temporary data for initial signup
  final String? initialCode; // Initial code sent if userData is present

  const EmailVerifyScreen({
    super.key,
    required this.email,
    required this.name,
    required this.role,
    this.userData,
    this.initialCode,
  });

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _timerSeconds = 60;
  Timer? _timer;
  String? _currentCode;
  DateTime? _currentTimestamp;

  @override
  void initState() {
    super.initState();
    _currentCode = widget.initialCode;
    _currentTimestamp = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    _timerSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyCode() async {
    String code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not found. Please log in again.');

      final collection = widget.role == 'client' ? 'clients' : 'service_providers';
      
      String? storedCode;
      DateTime? sentTime;

      if (widget.userData != null) {
        // Mode A: Creating new account after verification
        storedCode = _currentCode;
        sentTime = _currentTimestamp;
      } else {
        // Mode B: Verifying existing account (fallback for interrupted signup)
        final doc = await FirebaseFirestore.instance.collection(collection).doc(user.uid).get();
        if (!doc.exists) throw Exception('User data not found.');
        
        final data = doc.data() as Map<String, dynamic>;
        storedCode = data['verificationCode'];
        final Timestamp? ts = data['verificationCodeTimestamp'];
        sentTime = ts?.toDate();
      }

      if (storedCode == null || storedCode != code) {
        throw Exception('Invalid verification code. Please try again.');
      }

      // Check for expiration (10 minutes)
      if (sentTime != null) {
        final DateTime now = DateTime.now();
        final difference = now.difference(sentTime);
        if (difference.inMinutes >= 10) {
          throw Exception('Verification code has expired. Please resend a new one.');
        }
      }

      if (widget.userData != null) {
        // Create the account now
        Map<String, dynamic> finalUserData = Map.from(widget.userData!);
        finalUserData['isEmailVerified'] = true;
        finalUserData.remove('verificationCode');
        finalUserData.remove('verificationCodeTimestamp');
        
        await FirebaseFirestore.instance.collection(collection).doc(user.uid).set(finalUserData);
      } else {
        // Update verification status and clear the code
        await FirebaseFirestore.instance.collection(collection).doc(user.uid).update({
          'isEmailVerified': true,
          'verificationCode': FieldValue.delete(),
          'verificationCodeTimestamp': FieldValue.delete(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_timerSeconds > 0) return;

    setState(() => _isResending = true);

    try {
      final newCode = (Random().nextInt(900000) + 100000).toString();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not found.');

      if (widget.userData != null) {
        // Update local state only
        _currentCode = newCode;
        _currentTimestamp = DateTime.now();
      } else {
        // Update Firestore
        final collection = widget.role == 'client' ? 'clients' : 'service_providers';
        await FirebaseFirestore.instance.collection(collection).doc(user.uid).update({
          'verificationCode': newCode,
          'verificationCodeTimestamp': FieldValue.serverTimestamp(),
        });
      }

      await BrevoService.sendVerificationCode(widget.email, widget.name, newCode);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code resent!'), backgroundColor: Colors.green),
        );
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend code: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Verify Email'),
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
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_email_read_rounded, size: 64, color: Colors.white),
                      const SizedBox(height: 24),
                      const Text(
                        'Check Your Email',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We sent a 6-digit verification code to ${widget.email}. Enter it below to continue.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 45,
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                counterText: "",
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.white30),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.white, width: 2),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty && index < 5) {
                                  _focusNodes[index + 1].requestFocus();
                                }
                                if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                                if (index == 5 && value.isNotEmpty) {
                                  _verifyCode();
                                }
                              },
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2B5876),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Verify Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _timerSeconds > 0 || _isResending ? null : _resendCode,
                        child: Text(
                          _isResending
                              ? 'Sending...'
                              : _timerSeconds > 0
                                  ? 'Resend code in ${_timerSeconds}s'
                                  : 'Resend Code',
                          style: TextStyle(
                            color: _timerSeconds > 0 ? Colors.white38 : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                    ), // ClipRRect
                  ), // Padding
                ), // Center
              ), // ConstrainedBox
            ); // SingleChildScrollView
          },
        ),
      ),
    ),
  );
}
}
