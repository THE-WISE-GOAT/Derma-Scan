// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _tokenKey = 'auth_token';

  // Replace with your backend login URL
  final Uri loginUrl = Uri.parse('http://192.168.31.31:5001/login');

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      loginUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      // expect backend to return {"token": "...", "user": {...}}
      if (body['token'] != null) {
        await _saveToken(body['token']);
        return {'success': true, 'data': body};
      } else {
        return {'success': false, 'message': 'Invalid server response'};
      }
    } else {
      // try to parse server message or return generic error
      try {
        final body = jsonDecode(response.body);
        return {'success': false, 'message': body['message'] ?? 'Login failed'};
      } catch (_) {
        return {'success': false, 'message': 'Login failed (${response.statusCode})'};
      }
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }
}
