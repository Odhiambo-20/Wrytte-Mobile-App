import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wrytte/services/auth/real_number_service.dart';
import 'package:wrytte/ui/auth/country_picker_page.dart';
import 'package:wrytte/ui/screens/terms_privacy_page.dart';
import 'package:wrytte/utils/countries.dart';
import 'otp_verification_page.dart';

class PhoneAuthPage extends StatefulWidget {
  final bool isSignInFlow;

  const PhoneAuthPage({super.key, this.isSignInFlow = false});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  Country? _selectedCountry;
  final TextEditingController _numberCtrl = TextEditingController();
  final RealNumberService _realNumberService = RealNumberService();

  bool _isSending = false;

  ///  Dial code
  String get _dialCode => _selectedCountry?.dialCode ?? '';

  ///  Full phone with normalization (remove leading 0)
  String get _fullPhone {
    if (_selectedCountry == null) return '';
    final raw = _numberCtrl.text.trim();
    final normalized = raw.startsWith('0') ? raw.substring(1) : raw;
    return '+$_dialCode$normalized';
  }

  ///  Validation: country selected + phone >= 8 digits
  bool get _isValid =>
      _selectedCountry != null && _numberCtrl.text.trim().length >= 8;

  ///  Pick country
  Future<void> _pickCountry() async {
    final result = await Navigator.of(context).push<Country>(
      MaterialPageRoute(builder: (_) => const CountryPickerPage()),
    );

    if (result != null) {
      setState(() => _selectedCountry = result);
    }
  }

  ///  Start SMS verification
  Future<void> _startVerification() async {
    if (!_isValid || _isSending) return;

    setState(() => _isSending = true);

    try {
      await _realNumberService.sendSmsCode(_fullPhone);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => OtpVerificationPage(
                phoneNumber: _fullPhone,
                isSignInFlow: widget.isSignInFlow,
              ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send verification code."),
          backgroundColor: Colors.red,
        ),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F1013),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Back Button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(height: 10),

                /// Title
                const Center(
                  child: Text(
                    "Phone number",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const Center(
                  child: Text(
                    "Please confirm your country code\nand enter your phone number.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ),

                const SizedBox(height: 30),

                /// Country + Phone Container
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF23262C),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      /// Country Selector
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

                      /// Phone Row
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
                                controller: _numberCtrl,
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

                const SizedBox(height: 25),

                /// Terms Text
                Wrap(
                  children: [
                    const Text(
                      "By entering this device’s phone number and tapping “Next,” you agree to ",
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

                const SizedBox(height: 40),

                /// Next Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isValid && !_isSending ? _startVerification : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isValid
                              ? const Color(0xFF4DA3FF)
                              : const Color(0xFF23262C),
                      disabledBackgroundColor: const Color(0xFF23262C),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child:
                        _isSending
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
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
