import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:handy_link/services/brevo_service.dart';
import 'package:handy_link/email_verify_screen.dart';

class ClientSignupPage extends StatefulWidget {
  const ClientSignupPage({super.key});

  @override
  State<ClientSignupPage> createState() => _ClientSignupPageState();
}

class _ClientSignupPageState extends State<ClientSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;


  Future<void> _signUp() async {
  if (_formKey.currentState!.validate()) {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Create user in Firebase Authentication
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Get unique user ID
      String uid = userCredential.user!.uid;

      // 3. Generate verification code
      String verificationCode = (Random().nextInt(900000) + 100000).toString();

      // 4. Prepare additional user information (DO NOT save to Firestore yet)
      Map<String, dynamic> userData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'uid': uid,
        'isSuspended': false,
        'isEmailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 5. Send verification email via Brevo
      await BrevoService.sendVerificationCode(
        _emailController.text.trim(),
        _firstNameController.text.trim(),
        verificationCode,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your email.'),
            backgroundColor: Colors.blue,
          ),
        );

        // 6. Navigate to Verification Screen with user data
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerifyScreen(
              email: _emailController.text.trim(),
              name: _firstNameController.text.trim(),
              role: 'client',
              userData: userData,
              initialCode: verificationCode,
            ),
          ),
        );

        if (result == true && mounted) {
           Navigator.pop(context); // Go back after success
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          // Attempt to sign in to check status
          final signInResult = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          
          final uid = signInResult.user!.uid;
          final doc = await FirebaseFirestore.instance.collection('clients').doc(uid).get();
          
          if (!doc.exists) {
            // CASE: Auth account exists but Firestore record doesn't (unverified)
            // We'll use the data currently in the form fields to proceed
            String verificationCode = (Random().nextInt(900000) + 100000).toString();
            
            Map<String, dynamic> userData = {
               'firstName': _firstNameController.text.trim(),
               'lastName': _lastNameController.text.trim(),
               'email': _emailController.text.trim(),
               'phoneNumber': _phoneController.text.trim(),
               'uid': uid,
               'isSuspended': false,
               'isEmailVerified': false,
               'createdAt': FieldValue.serverTimestamp(),
            };

            await BrevoService.sendVerificationCode(
              _emailController.text.trim(),
              _firstNameController.text.trim(),
              verificationCode,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unverified account found. A new code has been sent.'), backgroundColor: Colors.blue),
              );
              
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmailVerifyScreen(
                    email: _emailController.text.trim(),
                    name: _firstNameController.text.trim(),
                    role: 'client',
                    userData: userData,
                    initialCode: verificationCode,
                  ),
                ),
              );
              if (result == true && mounted) Navigator.pop(context);
            }
            return;
          } else if (doc.data()?['isEmailVerified'] == false) {
            // CASE: Firestore record exists but is not verified (Legacy support or resending)
            String verificationCode = (Random().nextInt(900000) + 100000).toString();
            
            await FirebaseFirestore.instance.collection('clients').doc(uid).update({
              'verificationCode': verificationCode,
              'verificationCodeTimestamp': FieldValue.serverTimestamp(),
            });

            await BrevoService.sendVerificationCode(
              _emailController.text.trim(),
              doc.data()?['firstName'] ?? 'Client',
              verificationCode,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unverified account found. A new code has been sent.'), backgroundColor: Colors.blue),
              );
              
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmailVerifyScreen(
                    email: _emailController.text.trim(),
                    name: doc.data()?['firstName'] ?? 'Client',
                    role: 'client',
                  ),
                ),
              );
              if (result == true && mounted) Navigator.pop(context);
            }
            return;
          }
        } catch (_) {
          // If sign-in fails (e.g. wrong password), fall through to default error handling
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Signup failed"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Sign Up'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Your Client Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureConfirmPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
