import 'package:flutter/material.dart';
import 'package:wrytte/services/auth/api_service.dart';

class RealNumberService {
  RealNumberService();

  /// STEP 1: Send SMS verification code
  Future<void> sendSmsCode(String phone) async {
    try {
      debugPrint(" Sending SMS code to: $phone");

      final Map<String, String> body = {'phone': phone};

      await ApiService.postMultipart('/auth/register/sendsmscode', body);

      debugPrint(" SMS code request accepted");
    } catch (e) {
      debugPrint(" SMS code request failed: $e");
      rethrow;
    }
  }

  /// STEP 2: Register real phone number
  Future<RealNumberRegisterResult> registerRealPhone({
    required String phone,
    required String code,
    bool login = false,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'phone': phone,
        'code': code,
        'login': login.toString(),
      };

      final Map<String, dynamic> response = await ApiService.post(
        '/auth/register/rpn',
        body: body,
      );

      return RealNumberRegisterResult.fromJson(response);
    } on ApiException catch (e) {
      throw Exception('Real phone registration failed: ${e.message}');
    }
  }
}

class RealNumberRegisterResult {
  final String username;
  final String userId;
  final String secret;

  RealNumberRegisterResult({
    required this.username,
    required this.userId,
    required this.secret,
  });

  factory RealNumberRegisterResult.fromJson(Map<String, dynamic> json) {
    return RealNumberRegisterResult(
      username: json['username'] ?? '',
      userId: json['userid'] ?? '',
      secret: json['secret'] ?? '',
    );
  }
}
