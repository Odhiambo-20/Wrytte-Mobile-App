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

  // EMAIL REGISTRATION

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
      await _persistAuth(user);
    }

    return user;
  }

  // REAL PHONE REGISTRATION

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
      await _persistAuth(user);
    }

    return user;
  }

  // LOGIN

  Future<AuthUser> login({
    required String phone,
    required String secret,
    String? userid,
    String? username,
  }) async {
    final result = await ApiService.post(
      "/auth/login",
      body: {
        "phone": phone,
        "secret": secret,
        if (userid != null) "userid": userid,
        if (username != null) "username": username,
      },
    );

    final user = AuthUser.fromJson(result);

    await _persistAuth(user);

    return user;
  }

  // NEW WRYTTE PRODUCTION AUTH FLOW
  Future<AuthUser> authenticatePhone({
    required String phone,
    required String code,
    required String secret,
    String? username,
  }) async {
    try {
      // Trying login first
      final user = await login(
        phone: phone,
        secret: secret,
        username: username,
      );

      return user;
    } catch (_) {
      // If login fails - register user
      final user = await registerRealPhone(
        phone: phone,
        code: code,
        username: username,
        login: true,
      );

      return user;
    }
  }

  // PERSIST AUTH

  Future<void> _persistAuth(AuthUser user) async {
    await _storage.write(key: _tokenKey, value: user.token);

    await _storage.write(
      key: _expiryKey,
      value: user.expiresAt?.toUtc().toIso8601String(),
    );

    await _storage.write(key: _userIdKey, value: user.userId);
    await _storage.write(key: _usernameKey, value: user.username);
    await _storage.write(key: _secretKey, value: user.secret);
  }

  // LOAD CURRENT USER

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

  // LOGOUT

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
