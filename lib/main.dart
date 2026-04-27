import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:wrytte/ui/auth/auth_entry_screen.dart';
import 'package:wrytte/ui/auth/email_verification_page.dart';
import 'package:wrytte/ui/auth/login_email_verification_page.dart';
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
import 'package:wrytte/services/chat/chat_service.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

const _systemBarColor = Colors.transparent;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  /// TRUE EDGE-TO-EDGE
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  /// SYSTEM BAR COLOR
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: _systemBarColor,
      systemNavigationBarColor: _systemBarColor,
      systemNavigationBarDividerColor: _systemBarColor,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

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

        // LoginOtpPage is always pushed directly from SignInPage —
        // this is a safe fallback redirect in case anything still
        // references the named route.
        '/login_otp_page': (context) => const ThemeWrapper(child: SignInPage()),

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
  String? _currentUserId;

  final CallListenerService _callListener = CallListenerService();
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _callListener.stopListening();
    _chatService.disconnect();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    try {
      // ── Primary check: Firebase persistent session ──────────────────
      // Firebase automatically restores the session across app restarts.
      // If the user is signed in with Firebase, we trust that and use
      // their Firebase UID as the userId for the session.
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        // Firebase says the user is signed in — go straight to HomeScreen
        await _onAuthSuccess(firebaseUser.uid);
        return;
      }

      // ── Fallback: custom backend token check ────────────────────────
      // Handles users who were logged in via the custom backend before
      // Firebase auth was introduced.
      final loggedIn = await AuthService.instance.isLoggedIn();

      if (!mounted) return;
      FlutterNativeSplash.remove();

      if (loggedIn) {
        final currentUser = await AuthService.instance.getCurrentUser();
        final userId = currentUser?.userId;

        if (userId != null) {
          await _onAuthSuccess(userId);
          return;
        }
      }

      // Not logged in via either method
      if (!mounted) return;
      FlutterNativeSplash.remove();
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Auth check error: $e");
      if (!mounted) return;
      FlutterNativeSplash.remove();
      setState(() {
        _isLoading = false;
        _isLoggedIn = false;
      });
    }
  }

  // ── Shared setup once auth is confirmed ──────────────────────────────────

  Future<void> _onAuthSuccess(String userId) async {
    if (!mounted) return;
    FlutterNativeSplash.remove();

    try {
      await _chatService.connect();
      debugPrint("ChatService connected successfully");
    } catch (e) {
      debugPrint("ChatService connection error: $e");
    }

    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
      _isLoading = false;
      _currentUserId = userId;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _callListener.startListening(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF08090B),
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

    return HomeScreen(currentUserId: _currentUserId!);
  }
}
