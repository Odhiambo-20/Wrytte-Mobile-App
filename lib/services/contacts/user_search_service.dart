import 'dart:convert';
import 'package:http/http.dart' as http;

class UserSearchService {
  static const String baseUrl = "https://wryttedev.azurewebsites.net";

  Future<List<Map<String, dynamic>>> searchUsersByPhones(
    List<String> phoneNumbers,
    String token,
  ) async {
    final uri = Uri.parse("$baseUrl/api/users/search");

    final request = http.MultipartRequest("POST", uri);

    /// send phones as array
    for (final phone in phoneNumbers) {
      request.fields.addAll({"phoneNumbers": phone});
    }

    request.headers['Authorization'] = 'Bearer $token';

    final response = await request.send();

    final body = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(body));
    } else {
      throw Exception("Search failed: $body");
    }
  }
}
