// lib/ui/auth/sign_in_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wrytte/services/auth/auth_service.dart';
import 'package:wrytte/services/auth/real_number_service.dart';
import 'package:wrytte/ui/auth/country_picker_page.dart';
import 'package:wrytte/ui/auth/otp_verification_page.dart';
import 'package:wrytte/ui/auth/phone_auth_page.dart';
import 'package:wrytte/ui/screens/home_screen.dart';
import 'package:wrytte/utils/countries.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  Country? _selectedCountry;
  final TextEditingController _phoneController = TextEditingController();
  final RealNumberService _realNumberService = RealNumberService();
  final AuthService _authService = AuthService.instance;

  bool _isLoading = false;
  bool _isCheckingStoredUser = true;
  String? _storedPhone;
  String? _errorMessage;

  /// Dial code
  String get _dialCode => _selectedCountry?.dialCode ?? '';

  /// Full phone with normalization (remove leading 0)
  String get _fullPhone {
    if (_selectedCountry == null) return '';
    final raw = _phoneController.text.trim();
    final normalized = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+$_dialCode$normalized';
  }

  /// Validation: country selected + phone >= 8 digits
  bool get _isValid =>
      _selectedCountry != null && _phoneController.text.trim().length >= 8;

  @override
  void initState() {
    super.initState();
    _checkStoredUser();
  }

  /// Check if there's a stored user and pre-fill phone if available
  Future<void> _checkStoredUser() async {
    setState(() => _isCheckingStoredUser = true);

    try {
      final storedPhone = await _authService.getSavedPhone();
      final user = await _authService.getCurrentUser();

      if (storedPhone != null && storedPhone.isNotEmpty && mounted) {
        setState(() {
          _storedPhone = storedPhone;
        });

        // Parse the stored phone to pre-fill country and number
        _parseStoredPhone(storedPhone);
      }
    } catch (e) {
      debugPrint("Error checking stored user: $e");
    } finally {
      if (mounted) {
        setState(() => _isCheckingStoredUser = false);
      }
    }
  }

  /// Parse stored phone (e.g., "+256123456789") to extract country and number
  void _parseStoredPhone(String fullPhone) {
    // Try to find matching country by dial code
    for (var country in countries) {
      if (fullPhone.startsWith('+${country.dialCode}')) {
        setState(() {
          _selectedCountry = country;
          // Extract the number part without country code and +
          final numberPart = fullPhone.substring(country.dialCode.length + 1);
          _phoneController.text = numberPart;
        });
        return;
      }
    }

    // If no matching country found, just show the phone
    setState(() {
      _phoneController.text = fullPhone.replaceAll('+', '');
    });
  }

  /// Pick country
  Future<void> _pickCountry() async {
    final result = await Navigator.of(context).push<Country>(
      MaterialPageRoute(builder: (_) => const CountryPickerPage()),
    );

    if (result != null) {
      setState(() => _selectedCountry = result);
    }
  }

  /// Direct sign-in using stored secret
  Future<void> _signInWithStoredSecret() async {
    if (!_isValid || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    try {
      // Get the stored user which contains the secret
      final storedUser = await _authService.getCurrentUser();

      if (storedUser == null) {
        throw Exception("No stored credentials found. Please register first.");
      }

      debugPrint(
        "Attempting sign-in with stored secret for phone: $_fullPhone",
      );
      debugPrint("Stored user ID: ${storedUser.userId}");
      debugPrint("Stored username: ${storedUser.username}");

      // Attempt login using stored secret and the entered phone number
      final user = await _authService.login(
        secret: storedUser.secret,
        phone: _fullPhone, // Use the phone they just entered
        userid: storedUser.userId,
        username: storedUser.username.isNotEmpty ? storedUser.username : null,
      );

      if (!mounted) return;

      // Success - navigate to home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(currentUserId: '')),
        (_) => false,
      );
    } catch (e) {
      HapticFeedback.heavyImpact();

      String errorMsg = e.toString().replaceAll('ApiException: ', '');

      if (errorMsg.contains('401') ||
          errorMsg.contains('403') ||
          errorMsg.contains('Invalid')) {
        errorMsg =
            "Incorrect phone number or credentials. Please verify your phone number.";
      } else if (errorMsg.isEmpty) {
        errorMsg = "Sign in failed. Please try again.";
      }

      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  /// Fallback: Send OTP for verification (if stored secret doesn't work)
  Future<void> _sendOtpAndVerify() async {
    if (!_isValid || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Send OTP
      await _realNumberService.sendSmsCode(_fullPhone);

      if (!mounted) return;

      // Navigate to OTP verification with sign-in flow
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => OtpVerificationPage(
                phoneNumber: _fullPhone,
                isSignInFlow: true, // This tells OTP page it's for sign-in
              ),
        ),
      ).then((_) {
        // When returning from OTP page, reset loading state
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = "Failed to send verification code. Please try again.";
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1013),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Sign In",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child:
            _isCheckingStoredUser
                ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF4DA3FF)),
                      SizedBox(height: 16),
                      Text(
                        "Checking for existing account...",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Info text
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4DA3FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4DA3FF).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF4DA3FF),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Quick Sign In",
                                    style: TextStyle(
                                      color: Color(0xFF4DA3FF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Enter your phone number to sign in with your existing account",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Stored account indicator
                      if (_storedPhone != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF23262C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Existing Account Detected",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      "We found an account with phone: $_storedPhone",
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Phone number entry (similar to PhoneAuthPage)
                      const Text(
                        "Phone number",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF23262C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                _errorMessage != null
                                    ? Colors.redAccent
                                    : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Country Selector
                            ListTile(
                              onTap: _pickCountry,
                              title: Text(
                                _selectedCountry == null
                                    ? "Select Country"
                                    : "${_selectedCountry!.flag} ${_selectedCountry!.name}",
                                style: TextStyle(
                                  color:
                                      _selectedCountry == null
                                          ? Colors.white38
                                          : Colors.white,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.white54,
                              ),
                            ),

                            const Divider(color: Colors.white12, height: 1),

                            // Phone Row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  if (_selectedCountry != null)
                                    Text(
                                      "+$_dialCode",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  if (_selectedCountry != null)
                                    const SizedBox(width: 12),
                                  if (_selectedCountry != null)
                                    const SizedBox(
                                      height: 30,
                                      child: VerticalDivider(
                                        color: Colors.white24,
                                        width: 1,
                                      ),
                                    ),
                                  if (_selectedCountry != null)
                                    const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: "Phone number",
                                        hintStyle: TextStyle(
                                          color: Colors.white38,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (_) {
                                        setState(() {
                                          _errorMessage = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Hint about stored secret
                      const Text(
                        "We'll automatically use your stored credentials to sign you in securely.",
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),

                      const SizedBox(height: 30),

                      // Sign In Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _isValid && !_isLoading
                                  ? _signInWithStoredSecret
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4DA3FF),
                            disabledBackgroundColor: const Color(0xFF23262C),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text(
                                    "Sign In",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Alternative option
                      Center(
                        child: TextButton(
                          onPressed:
                              _isValid && !_isLoading
                                  ? _sendOtpAndVerify
                                  : null,
                          child: Text(
                            "Verify with OTP instead",
                            style: TextStyle(
                              color:
                                  _isValid
                                      ? const Color(0xFF4DA3FF)
                                      : Colors.white38,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white24)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "New here?",
                              style: TextStyle(color: Colors.white38),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white24)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Register option
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => const PhoneAuthPage(
                                      isSignInFlow: false,
                                    ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF4DA3FF)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Create New Account",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
