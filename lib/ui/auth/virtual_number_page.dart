import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wrytte/services/auth/virtual_number_service.dart';
import 'package:wrytte/ui/auth/email_verification_page.dart';
import 'package:wrytte/ui/screens/terms_privacy_page.dart';

class VirtualNumberPage extends StatefulWidget {
  const VirtualNumberPage({super.key});

  @override
  State<VirtualNumberPage> createState() => _VirtualNumberPageState();
}

class _VirtualNumberPageState extends State<VirtualNumberPage> {
  final TextEditingController _emailCtrl = TextEditingController();

  final VirtualNumberService _service = VirtualNumberService(
    baseUrl: "https://wryttedev.azurewebsites.net",
  );

  bool _isLoading = false;
  bool _emailValid = false;
  bool _vpnLoading = true;

  String _virtualNumber = "";

  @override
  void initState() {
    super.initState();
    _fetchVpn();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  ///  STEP 1: Fetch VPN from backend
  Future<void> _fetchVpn() async {
    setState(() {
      _vpnLoading = true;
      _virtualNumber = ""; // clear old number while loading
    });

    try {
      final phone = await _service.getAvailableVpn();

      if (!mounted) return;

      setState(() {
        _virtualNumber = phone;
        _vpnLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _vpnLoading = false);

      debugPrint("Virtual number fetch error: $e");

      // Show user-friendly message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to fetch Wrytte ID number"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  ///  STEP 2: Validate email input
  void _validateEmail(String? value) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    setState(() {
      _emailValid = value != null && emailRegex.hasMatch(value.trim());
    });
  }

  ///  STEP 3: Send email verification code
  Future<void> _submit() async {
    if (!_emailValid || _isLoading || _virtualNumber.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _service.sendEmailCode(_emailCtrl.text.trim());

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => EmailVerificationPage(
                email: _emailCtrl.text.trim(),
                virtualNumber: _virtualNumber,
              ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send verification email"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1013),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              ///  BACK
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              const SizedBox(height: 16),

              /// TITLE
              const Text(
                "Wrytte ID number",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Please enter your Email.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),

              const SizedBox(height: 8),

              ///  CHOOSE ANOTHER
              GestureDetector(
                onTap: _vpnLoading ? null : _fetchVpn,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "Choose another ",
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    Text(
                      "Wrytte ID number",
                      style: TextStyle(color: Color(0xFF4DA3FF), fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              /// INPUT CARD
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF23262C),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ///  VIRTUAL NUMBER (FROM BACKEND)
                    _vpnLoading
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                        : Text(
                          "+ $_virtualNumber",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            letterSpacing: 1.1,
                          ),
                        ),

                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24),

                    ///  EMAIL INPUT
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      decoration: const InputDecoration(
                        hintText: "Enter your email",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onChanged: _validateEmail,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// Terms Text
              Wrap(
                children: [
                  const Text(
                    "By entering your email and tapping “Next,” you agree to ",
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

              const Spacer(),

              /// NEXT BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _emailValid && !_isLoading && !_vpnLoading
                          ? _submit
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _emailValid
                            ? const Color(0xFF4DA3FF)
                            : const Color(0xFF23262C),
                    disabledBackgroundColor: const Color(0xFF23262C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                            "Next",
                            style: TextStyle(fontSize: 16, color: Colors.white),
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
