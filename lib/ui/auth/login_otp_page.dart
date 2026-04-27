import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wrytte/services/auth/auth_service.dart';
import 'package:wrytte/ui/screens/home_screen.dart';

class LoginOtpPage extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;

  const LoginOtpPage({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<LoginOtpPage> createState() => _LoginOtpPageState();
}

class _LoginOtpPageState extends State<LoginOtpPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  // May update after a resend
  late String _verificationId;
  int? _resendToken;

  int _secondsRemaining = 60;
  bool _canResend = false;
  Timer? _timer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  bool get _isValid => _otpController.text.length == 6;

  @override
  void initState() {
    super.initState();

    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;

    _startResendTimer();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(_shakeController);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _startResendTimer() {
    _secondsRemaining = 60;
    _canResend = false;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        if (mounted) setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (!_isValid || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1 — Verify OTP with Firebase
      await AuthService.instance.verifyFirebaseOtp(
        verificationId: _verificationId,
        smsCode: _otpController.text,
      );

      // Step 2 — Firebase verified, now log in via custom backend
      // using stored credentials (secret + userId) — no OTP needed here
      final savedUser = await AuthService.instance.getCurrentUser();

      if (savedUser == null ||
          savedUser.secret.isEmpty ||
          savedUser.userId.isEmpty) {
        // First time login — no stored credentials yet,
        // just navigate to home using the Firebase phone number as identity
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(currentUserId: widget.phoneNumber),
          ),
          (_) => false,
        );
        return;
      }

      // Returning user — log in with stored secret
      final user = await AuthService.instance.login(
        secret: savedUser.secret,
        userid: savedUser.userId,
        phone: widget.phoneNumber,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(currentUserId: user.userId),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      _shakeController.forward(from: 0);
      setState(() {
        _isLoading = false;
        _errorMessage =
            e.code == 'invalid-verification-code'
                ? 'Invalid code. Please try again.'
                : e.code == 'session-expired'
                ? 'Code expired. Please resend.'
                : 'Verification failed. Try again.';
        _otpController.clear();
      });
    } catch (e) {
      _shakeController.forward(from: 0);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid or expired code.';
        _otpController.clear();
      });
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Resend via AuthService — gets a fresh verificationId + resendToken
      final result = await AuthService.instance.resendFirebaseOtp(
        phoneNumber: widget.phoneNumber,
        resendToken: _resendToken,
      );

      if (!mounted) return;

      setState(() {
        _verificationId = result['verificationId'] as String;
        _resendToken = result['resendToken'] as int?;
        _isLoading = false;
      });

      _startResendTimer();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Failed to resend code.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to resend code.';
      });
    }
  }

  Widget _buildOtpBoxes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final boxSize = (screenWidth - 48) / 6;
        final boxWidth = boxSize.clamp(36.0, 48.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final char =
                index < _otpController.text.length
                    ? _otpController.text[index]
                    : '';

            return Container(
              width: boxWidth,
              height: boxWidth + 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF23262C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                char.isEmpty ? "—" : char,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1013),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                "Login verification",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "We've sent a code by SMS to phone\nnumber ${widget.phoneNumber}.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),

              const SizedBox(height: 30),

              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF23262C),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Enter 6-digit code",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      _buildOtpBoxes(),
                      TextField(
                        controller: _otpController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 6,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: "",
                        ),
                        style: const TextStyle(color: Colors.transparent),
                        cursorColor: Colors.transparent,
                        onChanged: (_) {
                          setState(() {});
                          if (_otpController.text.length == 6) {
                            _verifyOtp();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),

              const SizedBox(height: 20),

              Text(
                "00:${_secondsRemaining.toString().padLeft(2, '0')}",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: _canResend && !_isLoading ? _resendCode : null,
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            )
                            : const Text(
                              "Resend SMS",
                              style: TextStyle(color: Colors.white54),
                            ),
                  ),
                  const Text(
                    "Activate via call",
                    style: TextStyle(color: Colors.white54),
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
