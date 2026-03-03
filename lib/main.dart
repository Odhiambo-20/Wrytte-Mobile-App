import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:wrytte/ui/auth/auth_entry_screen.dart';
import 'package:wrytte/ui/auth/email_verification_page.dart';
import 'package:wrytte/ui/auth/login_email_verification_page.dart';
import 'package:wrytte/ui/auth/login_otp_page.dart';
import 'package:wrytte/ui/auth/phone_auth_page.dart';
import 'package:wrytte/ui/auth/otp_verification_page.dart';
import 'package:wrytte/ui/auth/add_profile_page.dart';
import 'package:wrytte/ui/auth/sign_in_page.dart';
import 'package:wrytte/ui/auth/virtual_number_page.dart';

import 'package:wrytte/ui/screens/home_screen.dart';
import 'package:wrytte/ui/screens/terms_privacy_page.dart';
import 'package:wrytte/ui/widgets/theme_wrapper.dart';

import 'package:wrytte/services/call_listener_service.dart';
import 'package:wrytte/services/auth/auth_service.dart';

import 'firebase_options.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase kept temporarily for compatibility with other files
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const WrytteApp());
}

class WrytteApp extends StatelessWidget {
  const WrytteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wrytte',
      debugShowCheckedModeBanner: false,
      theme: WrytteTheme.lightTheme,
      home: const ThemeWrapper(child: AuthWrapper()),
      routes: {
        '/auth_entry_screen':
            (context) => const ThemeWrapper(child: AuthEntryScreen()),

        '/phone_auth': (context) => const ThemeWrapper(child: PhoneAuthPage()),

        '/virtual_phone':
            (context) => const ThemeWrapper(child: VirtualNumberPage()),

        '/sign_in': (context) => const ThemeWrapper(child: SignInPage()),

        '/otp_verification': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;

          return ThemeWrapper(
            child: OtpVerificationPage(
              phoneNumber: args?['phoneNumber'] ?? '',
              isSignInFlow: args?['isSignInFlow'] ?? false,
            ),
          );
        },

        '/email_verification': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;

          return ThemeWrapper(
            child: EmailVerificationPage(
              email: args?['email'] ?? '',
              virtualNumber: args?['virtualNumber'] ?? '',
            ),
          );
        },

        "/login_otp_page": (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;

          return ThemeWrapper(
            child: LoginOtpPage(phoneNumber: args?['phone'] ?? ''),
          );
        },

        "/login_email_verification_page": (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;

          return ThemeWrapper(
            child: LoginEmailVerificationPage(
              email: args?['email'] ?? '',
              virtualNumber: args?['wrytteId'] ?? '',
            ),
          );
        },

        '/add_profile':
            (context) => const ThemeWrapper(child: AddProfilePage()),

        '/home': (context) => const ThemeWrapper(child: AuthWrapper()),

        'terms_privacy':
            (context) => const ThemeWrapper(child: TermsPrivacyPage()),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _currentUserId; // <-- Store logged-in user ID

  final CallListenerService _callListener = CallListenerService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _callListener.stopListening();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final loggedIn = await AuthService.instance.isLoggedIn();

      if (!mounted) return;

      // Get the current user from AuthService
      final currentUser = await AuthService.instance.getCurrentUser();
      final userId = currentUser?.userId;

      if (loggedIn && userId != null) {
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
          _currentUserId = userId;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _callListener.startListening(context);
        });
      } else {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Auth check error: $e");

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoggedIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1013),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (!_isLoggedIn) {
      return const AuthEntryScreen();
    }

    // Pass currentUserId to HomeScreen
    return HomeScreen(currentUserId: _currentUserId!);
  }
}
