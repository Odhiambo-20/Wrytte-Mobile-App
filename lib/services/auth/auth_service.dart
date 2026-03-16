import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wrytte/models/auth_models/auth_user.dart';
import 'api_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = "auth_token";
  static const _expiryKey = "auth_token_expiry";
  static const _userIdKey = "user_id";
  static const _usernameKey = "username";
  static const _secretKey = "secret";
  static const _phoneKey = "phone";

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
    await _storage.deleteAll();
  }
}
