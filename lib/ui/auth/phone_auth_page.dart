import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wrytte/ui/auth/country_picker_page.dart';
import 'package:wrytte/utils/countries.dart';
import 'otp_verification_page.dart';

class PhoneAuthPage extends StatefulWidget {
  final bool isSignInFlow;

  const PhoneAuthPage({super.key, this.isSignInFlow = false});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  final _formKey = GlobalKey<FormState>();
  Country? _selectedCountry;
  final TextEditingController _numberCtrl = TextEditingController();
  bool _isSending = false;
  bool _isCheckingNumber = false;

  String get _dialCode => _selectedCountry?.dialCode ?? '';
  String get _fullPhone =>
      _dialCode.isEmpty ? '' : '+$_dialCode${_numberCtrl.text.trim()}';

  Future<void> _pickCountry() async {
    final result = await Navigator.of(context).push<Country>(
      MaterialPageRoute(builder: (_) => const CountryPickerPage()),
    );
    if (result != null) {
      setState(() => _selectedCountry = result);
    }
  }

  Future<bool> _isPhoneNumberRegistered(String phoneNumber) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: phoneNumber)
              .limit(1)
              .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking phone number: $e');
      return false;
    }
  }

  Future<void> _startVerification() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _isSending) return;

    setState(() => _isSending = true);

    try {
      // Check if phone number is already registered for sign-up flow
      if (!widget.isSignInFlow) {
        setState(() => _isCheckingNumber = true);
        final isRegistered = await _isPhoneNumberRegistered(_fullPhone);
        setState(() => _isCheckingNumber = false);

        if (isRegistered) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This number is already registered. Please sign in instead.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _isSending = false);
          return;
        }
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _fullPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) {
          // Optional auto-complete on mobile only
        },
        verificationFailed: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'Verification failed'),
              backgroundColor: Colors.red,
            ),
          );
        },
        codeSent: (verificationId, _) async {
          try {
            await FirebaseFirestore.instance
                .collection('auth_requests')
                .doc(verificationId)
                .set({
                  'phone': _fullPhone,
                  'country': _selectedCountry?.name,
                  'isoCode': _selectedCountry?.isoCode,
                  'dialCode': _dialCode,
                  'status': 'codeSent',
                  'isSignIn': widget.isSignInFlow,
                  'createdAt': FieldValue.serverTimestamp(),
                });
          } catch (_) {}

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => OtpVerificationPage(
                    verificationId: verificationId,
                    phoneNumber: _fullPhone,
                    isSignInFlow: widget.isSignInFlow,
                  ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            children: [
              const SizedBox(height: 16),
              Text(
                widget.isSignInFlow ? 'Sign in to Wrytte' : 'Your phone number',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.isSignInFlow
                    ? 'Enter your phone number to sign in to your account'
                    : 'Please confirm your country code\nand enter your phone number.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 28),

              // Country selector
              GestureDetector(
                onTap: _pickCountry,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedCountry == null
                              ? 'Country'
                              : '${_selectedCountry!.flag} ${_selectedCountry!.name}',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                _selectedCountry == null
                                    ? Colors.black38
                                    : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.black45),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Phone number field
              TextFormField(
                controller: _numberCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 18, color: Colors.black),
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  labelStyle: const TextStyle(color: Colors.black87),
                  prefixText: _dialCode.isEmpty ? '' : '+$_dialCode ',
                  prefixStyle: const TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF42A5F5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1E88E5),
                      width: 2,
                    ),
                  ),
                ),
                validator: (_) {
                  if (_selectedCountry == null) {
                    return 'Select a country';
                  }
                  final n = _numberCtrl.text.trim();
                  if (n.isEmpty) return 'Enter your number';
                  if (n.length < 6) return 'Number looks too short';
                  if (n.length > 15) return 'Number looks too long';
                  return null;
                },
              ),

              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 64,
                  width: 64,
                  child: ElevatedButton(
                    onPressed:
                        (_isSending ||
                                _selectedCountry == null ||
                                _isCheckingNumber)
                            ? null
                            : _startVerification,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: const Color(0xFF64B5F6),
                      elevation: 2,
                    ),
                    child:
                        _isSending || _isCheckingNumber
                            ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                            ),
                  ),
                ),
              ),

              // Sign in/Sign up toggle
              if (!widget.isSignInFlow) ...[
                const SizedBox(height: 40),
                Divider(height: 1, color: Colors.grey[300]),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Start messaging with',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Wrytte',
                        style: TextStyle(
                          color: Color(0xFF1E88E5),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
