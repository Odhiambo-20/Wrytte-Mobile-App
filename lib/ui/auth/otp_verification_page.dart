import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wrytte/ui/auth/add_profile_page.dart';
import 'package:wrytte/ui/screens/home_screen.dart';

class OtpVerificationPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final bool isSignInFlow;

  const OtpVerificationPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.isSignInFlow = false,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int _secondsRemaining = 60;
  bool _canResend = false;
  Timer? _timer;
  String _currentVerificationId = '';

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startResendTimer();

    // Add a timeout for verification (5 minutes)
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted && _timer != null) {
        _timer?.cancel();
        setState(() {
          _errorMessage = 'Verification timed out. Please try again.';
          _canResend = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<bool> _checkUserProfileExists(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data();
        return data?['name'] != null &&
            data!['name'].toString().isNotEmpty &&
            data['username'] != null &&
            data['username'].toString().isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint("Error checking user profile: $e");
      return false;
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId:
            _currentVerificationId.isNotEmpty
                ? _currentVerificationId
                : widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null && mounted) {
        // Check if user has completed profile
        final hasProfile = await _checkUserProfileExists(user.uid);

        if (widget.isSignInFlow) {
          // For sign in flow, always go to home if profile exists
          if (hasProfile) {
            Navigator.pushReplacement(
              // ignore: use_build_context_synchronously
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          } else {
            // This shouldn't happen for signed in users, but handle gracefully
            Navigator.pushReplacement(
              // ignore: use_build_context_synchronously
              context,
              MaterialPageRoute(builder: (context) => const AddProfilePage()),
            );
          }
        } else {
          // For sign up flow, check if profile exists
          if (hasProfile) {
            // Profile already exists (edge case), go to home
            Navigator.pushReplacement(
              // ignore: use_build_context_synchronously
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          } else {
            // New user, go to add profile
            Navigator.pushReplacement(
              // ignore: use_build_context_synchronously
              context,
              MaterialPageRoute(builder: (context) => const AddProfilePage()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Verification failed. Please try again.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final hasProfile = await _checkUserProfileExists(user.uid);
              if (hasProfile) {
                Navigator.pushReplacement(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              } else {
                Navigator.pushReplacement(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddProfilePage(),
                  ),
                );
              }
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _errorMessage = e.message ?? 'Failed to resend code.';
              _isLoading = false;
            });
          }
        },
        codeSent: (String newVerificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _currentVerificationId = newVerificationId;
              _isLoading = false;
            });
            _startResendTimer();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verification code resent successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _currentVerificationId = verificationId;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to resend code. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          widget.isSignInFlow ? 'Sign In' : 'Verify Number',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isSignInFlow
                                ? 'Enter verification code'
                                : 'Verify your number',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'We have sent an SMS with a code to ',
                                ),
                                TextSpan(
                                  text: widget.phoneNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),

                      // OTP Input Field
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Enter 6-digit code',
                          labelStyle: const TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E88E5),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                        maxLength: 6,
                      ),

                      const SizedBox(height: 24),

                      // Error Message
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // This spacer will push the buttons to the bottom when there's enough space
                      const Expanded(child: SizedBox()),

                      // Buttons Section
                      Column(
                        children: [
                          // Verify Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed:
                                  (_isLoading ||
                                          _otpController.text.length != 6)
                                      ? null
                                      : _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Text(
                                        'Verify',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Resend Code
                          Center(
                            child: TextButton(
                              onPressed:
                                  _canResend && !_isLoading
                                      ? _resendCode
                                      : null,
                              child: Text(
                                _canResend
                                    ? "Resend code"
                                    : "Resend code in $_secondsRemaining seconds",
                                style: TextStyle(
                                  color:
                                      _canResend
                                          ? const Color(0xFF1E88E5)
                                          : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
