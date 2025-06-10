import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './token_storage.dart'; // Import the new TokenStorage

class AuthService {
  static final String? _backendUrl = dotenv.env['BACKEND_URL'];

  // Handles HTTP POST request for user signup
  // Returns a map with 'success', 'message', 'role', and 'token' (if successful)
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    String? role,
    String? saccoName,
    String? saccoOwner,
    String? driverLicenseNumber,
  }) async {
    if (_backendUrl == null) {
      return {'success': false, 'message': 'Backend URL not configured.'};
    }

    try {
      final url = Uri.parse('$_backendUrl/auth/signup');
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
      };

      if (role != null && role.isNotEmpty) {
        body['role'] = role;
      }

      // Add sacco-specific fields if role is 'sacco'
      if (role == 'sacco') {
        if (saccoName != null) body['sacco_name'] = saccoName;
        if (saccoOwner != null) body['sacco_owner'] = saccoOwner;
      }

      // Add driver-specific fields if role is 'driver'
      if (role == 'driver') {
        if (driverLicenseNumber != null) body['license_number'] = driverLicenseNumber;
      }

      // --- DEBUG PRINT ---
      print('AuthService.signup - Request Body before JSON encoding: $body');
      // --- END DEBUG PRINT ---

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String? responseRole = responseBody['user']?['role'];
        final String? token = responseBody['token'];

        if (token != null) {
          await TokenStorage.saveToken(token);
        }

        return {
          'success': true,
          'message': responseBody['message'] ?? 'Signup successful!',
          'role': responseRole,
          'token': token,
        };
      } else {
        return {'success': false, 'message': responseBody['error'] ?? 'Signup failed.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  // Your existing login method
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (_backendUrl == null) {
      return {'success': false, 'message': 'Backend URL not configured.'};
    }

    try {
      final url = Uri.parse('$_backendUrl/auth/login');
      final body = {
        'email': email,
        'password': password,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final String? role = responseBody['user']?['role'];
        final String? token = responseBody['token'];

        if (token != null) {
          await TokenStorage.saveToken(token);
        }

        return {
          'success': true,
          'message': responseBody['message'] ?? 'Login successful!',
          'role': role,
          'token': token,
        };
      } else {
        return {'success': false, 'message': responseBody['error'] ?? 'Login failed.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
}