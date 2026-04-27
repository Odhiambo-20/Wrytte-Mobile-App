import 'dart:convert';
import 'package:http/http.dart' as http;

class UserSearchService {
  static const String baseUrl = "https://wryttedev.azurewebsites.net";

  /// Send phone numbers to backend and get matched users
  Future<Map<String, String>> searchUsersByPhones({
    List<String>? phoneNumbersA,
    String? phoneNumbersC,
    required String token,
  }) async {
    final uri = Uri.parse("$baseUrl/api/users/search");

    String? phonesToSend;

    if (phoneNumbersC != null && phoneNumbersC.isNotEmpty) {
      phonesToSend = phoneNumbersC;
    } else if (phoneNumbersA != null && phoneNumbersA.isNotEmpty) {
      phonesToSend = phoneNumbersA.join('|');
    } else {
      return {};
    }

    try {
      final response = await http.post(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {"phoneNumbersC": phonesToSend},
      );

      if (response.statusCode != 200) {
        throw Exception("Search failed: ${response.body}");
      }

      if (response.body.isEmpty) {
        return {};
      }

      final decoded = jsonDecode(response.body);

      final Map<String, String> result = Map<String, String>.from(
        decoded as Map,
      );

      return result;
    } catch (e) {
      throw Exception("User search error: $e");
    }
  }
}
