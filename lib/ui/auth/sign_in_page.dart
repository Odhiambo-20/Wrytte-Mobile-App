import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wrytte/services/auth/auth_service.dart';
import 'package:wrytte/ui/auth/country_picker_page.dart';
import 'package:wrytte/ui/screens/terms_privacy_page.dart';
import 'package:wrytte/utils/countries.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _wrytteIdCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  Country? _selectedCountry;

  bool _isLoading = false;

  /// helpers
  String get _dialCode => _selectedCountry?.dialCode ?? '';

  String get _fullPhone {
    if (_selectedCountry == null) return '';
    final raw = _phoneCtrl.text.trim();
    final normalized = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+$_dialCode$normalized';
  }

  bool get _phoneValid =>
      _selectedCountry != null && _phoneCtrl.text.trim().length >= 8;

  bool get _wrytteValid =>
      _wrytteIdCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().contains("@");

  Future<void> _pickCountry() async {
    final result = await Navigator.push<Country>(
      context,
      MaterialPageRoute(builder: (_) => const CountryPickerPage()),
    );

    if (result != null) {
      setState(() => _selectedCountry = result);
    }
  }

  /// WRYTTE ID LOGIN

  Future<void> _loginWithWrytteId() async {
    if (!_wrytteValid || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      /// send login email code
      await AuthService.instance.sendEmailCode(_emailCtrl.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Verification code sent to your email"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushNamed(
        context,
        "/login_email_verification_page",
        arguments: {
          "email": _emailCtrl.text.trim(),
          "wrytteId": _wrytteIdCtrl.text.trim(),
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// PHONE LOGIN

  Future<void> _loginWithPhone() async {
    if (!_phoneValid || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      /// send sms login code
      await AuthService.instance.sendSmsCode(_fullPhone);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("SMS verification code sent"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushNamed(
        context,
        "/login_otp_page",
        arguments: {"phone": _fullPhone},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send login code: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _wrytteIdCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1013),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              /// BACK
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Sign In",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 30),

              /// WRYTTE LOGIN CARD
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF23262C),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _wrytteIdCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Wrytte ID",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const Divider(color: Colors.white24),

                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Email",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// WRYTTE LOGIN BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _wrytteValid ? _loginWithWrytteId : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _wrytteValid
                            ? const Color(0xFF4DA3FF)
                            : const Color(0xFF23262C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            "Continue",
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "OR",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),

              const SizedBox(height: 30),

              /// PHONE LOGIN
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF23262C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ListTile(
                      onTap: _pickCountry,
                      title: Text(
                        _selectedCountry == null
                            ? "Country"
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
                            const SizedBox(width: 10),

                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "Phone number",
                                hintStyle: TextStyle(color: Colors.white38),
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// PHONE LOGIN BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _phoneValid ? _loginWithPhone : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _phoneValid
                            ? const Color(0xFF4DA3FF)
                            : const Color(0xFF23262C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// TERMS
              Wrap(
                children: [
                  const Text(
                    "By signing in you agree to ",
                    style: TextStyle(color: Colors.white70),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsPrivacyPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Wrytte’s Terms and Conditions and Privacy Policy",
                      style: TextStyle(color: Color(0xFF4DA3FF)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
