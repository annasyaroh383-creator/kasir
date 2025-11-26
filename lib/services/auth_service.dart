import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl =
      'http://localhost:8000/api'; // Adjust for your backend URL

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      // TEMPORARY: Mock authentication for testing without backend
      // Remove this when Laravel backend is running
      if (email.isNotEmpty && password.length >= 6) {
        // Simulate successful login
        final mockToken =
            'mock_token_' + DateTime.now().millisecondsSinceEpoch.toString();
        final mockUser = {
          'id': 1,
          'name': 'Test Admin',
          'email': email,
          'role': 'admin',
        };

        // Save token to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', mockToken);
        await prefs.setString('user', jsonEncode(mockUser));

        print(
          'DEBUG: Mock login successful - Token saved: ${mockToken.substring(0, 20)}...',
        );
        print(
          'DEBUG: Mock login successful - User saved: ${mockUser['email']}',
        );

        return {'success': true, 'token': mockToken, 'user': mockUser};
      }

      return {'success': false, 'message': 'Invalid credentials'};

      /* ORIGINAL BACKEND CODE - Uncomment when PHP/Laravel is installed
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // Save token to shared preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString('user', jsonEncode(data['user']));

          print(
            'DEBUG: Login successful - Token saved: ${data['token'] != null ? "Token exists (${data['token'].length} chars)" : "NULL"}',
          );
          print(
            'DEBUG: Login successful - User saved: ${data['user'] != null ? data['user']['email'] : "NULL"}',
          );

          return {
            'success': true,
            'token': data['token'],
            'user': data['user'],
          };
        }
      }

      return {'success': false, 'message': 'Login failed'};
      */
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<bool> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print(
      'DEBUG: getToken() - Token from SharedPreferences: ${token != null ? "Token exists (${token.length} chars)" : "NULL"}',
    );
    return token;
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }
}
