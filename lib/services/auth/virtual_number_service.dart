import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wrytte/models/auth_models/auth_user.dart';

class VirtualNumberService {
  final String baseUrl;

  VirtualNumberService({required this.baseUrl});

  /// 1️ Get available VPN from backend
  Future<String> getAvailableVpn() async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/getavailablevpn'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch virtual number');
    }

    return response.body.trim();
  }

  /// 2️ Send email verification code
  Future<void> sendEmailCode(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/sendemailcode'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'email': email},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send email code');
    }
  }

  /// 3️ Verify email + activate VPN
  Future<AuthUser> registerVpn({
    required String email,
    required String code,
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/vpn'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'email': email,
        'code': code,
        'phone': phone,
        'username': email.split('@')[0], // auto username
        'login': 'true',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Invalid verification code');
    }

    return AuthUser.fromJson(jsonDecode(response.body));
  }
}
