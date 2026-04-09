import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wrytte/models/auth_models/auth_user.dart';
import 'api_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Firebase instance — used only for phone OTP verification
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  static const _tokenKey = "auth_token";
  static const _expiryKey = "auth_token_expiry";
  static const _userIdKey = "user_id";
  static const _usernameKey = "username";
  static const _secretKey = "secret";
  static const _phoneKey = "phone";

  // ───────────────── FIREBASE PHONE AUTH ─────────────────
  // These two methods handle Firebase OTP — completely separate
  // from your custom backend logic below. Call sendFirebaseOtp()
  // first, then verifyFirebaseOtp() with the code the user enters.

  /// Step 1 — Triggers Firebase to send an SMS OTP to [phoneNumber].
  /// Returns the verificationId and resendToken needed for step 2.
  Future<Map<String, dynamic>> sendFirebaseOtp(String phoneNumber) async {
    final completer = _OtpCompleter();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: null,

      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verified (instant verification on some Android devices)
        // Sign in silently — the UI flow will still complete normally
        await _firebaseAuth.signInWithCredential(credential);
      },

      verificationFailed: (FirebaseAuthException e) {
        completer.completeError(e);
      },

      codeSent: (String verificationId, int? resendToken) {
        completer.complete({
          'verificationId': verificationId,
          'resendToken': resendToken,
        });
      },

      codeAutoRetrievalTimeout: (_) {
        // Timeout — manual entry on OTP page handles this, nothing to do
      },
    );

    return completer.future;
  }

  /// Step 1b — Resend Firebase OTP using the previous [resendToken].
  /// Returns a fresh verificationId and resendToken.
  Future<Map<String, dynamic>> resendFirebaseOtp({
    required String phoneNumber,
    required int? resendToken,
  }) async {
    final completer = _OtpCompleter();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: resendToken,

      verificationCompleted: (PhoneAuthCredential credential) async {
        await _firebaseAuth.signInWithCredential(credential);
      },

      verificationFailed: (FirebaseAuthException e) {
        completer.completeError(e);
      },

      codeSent: (String verificationId, int? newResendToken) {
        completer.complete({
          'verificationId': verificationId,
          'resendToken': newResendToken,
        });
      },

      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  /// Step 2 — Verifies the OTP code the user typed against Firebase.
  /// Returns the signed-in Firebase [User] on success.
  /// Throws [FirebaseAuthException] on invalid/expired code.
  Future<User> verifyFirebaseOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Firebase returned a null user after sign in.',
      );
    }

    return firebaseUser;
  }

  /// Signs out from Firebase only — does not affect your custom backend session.
  Future<void> signOutFirebase() async {
    await _firebaseAuth.signOut();
  }

  /// Returns the currently signed-in Firebase user, or null if not signed in.
  User? get firebaseCurrentUser => _firebaseAuth.currentUser;

  // ───────────────── EMAIL REGISTRATION ─────────────────

  Future<void> sendEmailCode(String email) async {
    await ApiService.post(
      "/auth/register/sendemailcode",
      body: {"email": email},
    );
  }

  Future<AuthUser> registerVirtualPhone({
    required String email,
    required String code,
    required String phone,
    String? username,
    bool login = true,
  }) async {
    final result = await ApiService.post(
      "/auth/register/vpn",
      body: {
        "email": email,
        "code": code,
        "phone": phone,
        if (username != null) "username": username,
        "login": login,
      },
    );

    final user = AuthUser.fromJson(result);

    if (login) {
      await _persistAuth(user, phone: phone);
    }

    return user;
  }

  // ───────────────── PHONE REGISTRATION ─────────────────

  Future<void> sendSmsCode(String phone) async {
    await ApiService.post("/auth/register/sendsmscode", body: {"phone": phone});
  }

  Future<AuthUser> registerRealPhone({
    required String phone,
    required String code,
    String? username,
    bool login = true,
  }) async {
    final result = await ApiService.post(
      "/auth/register/rpn",
      body: {
        "phone": phone,
        "code": code,
        if (username != null) "username": username,
        "login": login,
      },
    );

    final user = AuthUser.fromJson(result);

    if (login) {
      await _persistAuth(user, phone: phone);
    }

    return user;
  }

  // ───────────────── LOGIN ─────────────────

  Future<AuthUser> login({
    required String secret,
    String? userid,
    String? phone,
    String? username,
  }) async {
    final body = <String, dynamic>{
      "secret": secret,
      if (userid != null && userid.isNotEmpty) "userid": userid,
      if (phone != null && phone.isNotEmpty) "phone": phone,
      if (username != null && username.isNotEmpty) "username": username,
    };

    final result = await ApiService.post("/auth/login", body: body);

    final user = AuthUser.fromJson(result);

    await _persistAuth(user, phone: phone);

    return user;
  }

  // ───────────────── SMART AUTH ─────────────────
  // Automatically decides whether to login or register

  Future<AuthUser> authenticatePhone({
    required String phone,
    required String code,
    String? username,
  }) async {
    final savedUser = await getCurrentUser();

    if (savedUser != null &&
        savedUser.secret.isNotEmpty &&
        savedUser.userId.isNotEmpty) {
      try {
        return await login(
          secret: savedUser.secret,
          userid: savedUser.userId,
          phone: phone,
          username: savedUser.username.isNotEmpty ? savedUser.username : null,
        );
      } catch (_) {
        // Stored credentials invalid → register again
      }
    }

    return await registerRealPhone(
      phone: phone,
      code: code,
      username: username,
      login: true,
    );
  }

  // ───────────────── SAVE AUTH DATA ─────────────────

  Future<void> _persistAuth(AuthUser user, {String? phone}) async {
    await _storage.write(key: _tokenKey, value: user.token);

    if (user.expiresAt != null) {
      await _storage.write(
        key: _expiryKey,
        value: user.expiresAt!.toUtc().toIso8601String(),
      );
    }

    await _storage.write(key: _userIdKey, value: user.userId);
    await _storage.write(key: _usernameKey, value: user.username);
    await _storage.write(key: _secretKey, value: user.secret);

    if (phone != null && phone.isNotEmpty) {
      await _storage.write(key: _phoneKey, value: phone);
    }
  }

  // ───────────────── LOAD CURRENT USER ─────────────────

  Future<AuthUser?> getCurrentUser() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;

    final expiryString = await _storage.read(key: _expiryKey);
    final userId = await _storage.read(key: _userIdKey) ?? '';
    final username = await _storage.read(key: _usernameKey) ?? '';
    final secret = await _storage.read(key: _secretKey) ?? '';

    return AuthUser(
      userId: userId,
      username: username,
      secret: secret,
      token: token,
      expiresAt: expiryString != null ? DateTime.tryParse(expiryString) : null,
    );
  }

  // ───────────────── HELPERS ─────────────────

  Future<String?> getSavedPhone() async {
    return await _storage.read(key: _phoneKey);
  }

  Future<String?> getCurrentUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();

    if (user == null) return false;
    if (user.isExpired) return false;

    return user.isAuthenticated;
  }

  // ───────────────── LOGOUT ─────────────────

  Future<void> logout() async {
    // Sign out from Firebase and clear custom backend session together
    await signOutFirebase();
    await _storage.deleteAll();
  }
}

// ───────────────── INTERNAL HELPER ─────────────────
// A simple Completer wrapper used to bridge Firebase's callback-based
// verifyPhoneNumber() into a clean async/await Future.

class _OtpCompleter {
  final _completer = Completer<Map<String, dynamic>>();

  void complete(Map<String, dynamic> value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  void completeError(Object error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }

  Future<Map<String, dynamic>> get future => _completer.future;
}
