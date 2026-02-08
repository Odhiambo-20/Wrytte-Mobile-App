import 'package:flutter/material.dart';
import 'package:flutter_statusbarcolor_ns/flutter_statusbarcolor_ns.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wrytte/ui/auth/phone_auth_page.dart';
import 'package:wrytte/ui/auth/otp_verification_page.dart';
import 'package:wrytte/ui/auth/add_profile_page.dart';
import 'package:wrytte/ui/auth/sign_in_page.dart';
import 'package:wrytte/ui/screens/chats/chats_screen.dart';
import 'package:wrytte/ui/screens/home_screen.dart';
import 'package:wrytte/ui/screens/message_screen.dart';
import 'package:wrytte/services/call_listener_service.dart';
import 'firebase_options.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully");
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  await setStatusBarAndNavigationBarColors();
  runApp(const WrytteApp());
}

Future<void> setStatusBarAndNavigationBarColors() async {
  try {
    await FlutterStatusbarcolor.setStatusBarColor(Colors.black);

    await FlutterStatusbarcolor.setNavigationBarColor(Colors.black);

    if (useWhiteForeground(Colors.black)) {
      FlutterStatusbarcolor.setStatusBarWhiteForeground(true);
      FlutterStatusbarcolor.setNavigationBarWhiteForeground(true);
    } else {
      FlutterStatusbarcolor.setStatusBarWhiteForeground(false);
      FlutterStatusbarcolor.setNavigationBarWhiteForeground(false);
    }
  } catch (e) {
    debugPrint("Error setting status/navigation bar colors: $e");
  }
}

class WrytteApp extends StatelessWidget {
  const WrytteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wrytte',
      debugShowCheckedModeBanner: false,
      theme: WrytteTheme.lightTheme,
      home: const AuthWrapper(),

      routes: {
        '/phone_auth': (context) => const PhoneAuthPage(),
        '/sign_in': (context) => const SignInPage(),
        '/otp_verification': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          return OtpVerificationPage(
            verificationId: args?['verificationId'] ?? '',
            phoneNumber: args?['phoneNumber'] ?? '',
          );
        },
        '/add_profile': (context) => const AddProfilePage(),
        '/chats_screen': (context) => const ChatsScreen(),
        '/homepage': (context) => const HomeScreen(),
        '/home_screen': (context) => const HomeScreen(),
        '/message_screen': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          return MessageScreen(
            name: args?['name'] ?? '',
            receiverId: args?['receiverId'] ?? '',
            avatarUrl: args?['avatarUrl'],
            chatId: args?['chatId'],
            isOnline: args?['isOnline'] ?? false,
          );
        },
      },

      onGenerateRoute: (settings) {
        debugPrint('Generating route for: ${settings.name}');

        return MaterialPageRoute(builder: (context) => const AuthWrapper());
      },
      onUnknownRoute: (settings) {
        debugPrint('Unknown route: ${settings.name}');
        return MaterialPageRoute(builder: (context) => const AuthWrapper());
      },
    );
  }
}

// Auth Wrapper to handle user session persistence
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _user;
  bool _isLoading = true;
  bool _hasProfile = false;
  String _loadingMessage = 'Loading Wrytte...';
  final CallListenerService _callListener = CallListenerService();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  @override
  void dispose() {
    _callListener.stopListening();
    super.dispose();
  }

  Future<void> _checkAuthState() async {
    try {
      _updateLoadingMessage('Checking authentication...');

      // Listen to auth state changes
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        if (user != null) {
          _updateLoadingMessage('Checking user profile...');
          // User is signed in, check if they have a profile
          final hasProfile = await _checkUserProfile(user.uid);
          setState(() {
            _user = user;
            _hasProfile = hasProfile;
            _isLoading = false;
          });

          // Start listening for incoming calls when user is authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _callListener.startListening(context);
          });
        } else {
          // User is not signed in
          setState(() {
            _user = null;
            _hasProfile = false;
            _isLoading = false;
          });
          _callListener.stopListening();
        }
      });

      // Also check initial state immediately
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _updateLoadingMessage('Loading user data...');
        final hasProfile = await _checkUserProfile(currentUser.uid);
        setState(() {
          _user = currentUser;
          _hasProfile = hasProfile;
          _isLoading = false;
        });

        // Start listening for incoming calls
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _callListener.startListening(context);
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error checking auth state: $e");
      _updateLoadingMessage('Error loading app. Please refresh...');
      // Wait a bit before showing error state
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateLoadingMessage(String message) {
    if (mounted) {
      setState(() {
        _loadingMessage = message;
      });
    }
  }

  Future<bool> _checkUserProfile(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      // Check if user has completed profile (has name and username)
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

  Widget _buildErrorWidget() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please refresh the page',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _checkAuthState();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                _loadingMessage,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Handle any unexpected null states
    if (_user == null && _hasProfile) {
      // Inconsistent state - reset to auth
      return const PhoneAuthPage();
    }

    // User flow logic
    try {
      if (_user == null) {
        // No user signed in - show phone auth
        return const PhoneAuthPage();
      } else if (!_hasProfile) {
        // User signed in but no profile - show add profile
        return const AddProfilePage();
      } else {
        // User signed in and has profile - show home screen
        return const HomeScreen();
      }
    } catch (e) {
      debugPrint("Error building auth wrapper: $e");
      return _buildErrorWidget();
    }
  }
}
