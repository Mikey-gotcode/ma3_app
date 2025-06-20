import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './token_storage.dart'; // Import the new TokenStorage

class AuthService {
  static final String? _backendUrl = dotenv.env['BACKEND_URL'];

  // Handles HTTP POST request for user signup
  // Returns a map with 'success', 'message', 'role', and 'token' (if successful)
   static Future<Map<String, dynamic>> _authenticatedFetch(String endpoint, {String method = 'GET', Map<String, dynamic>? body}) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      return {'success': false, 'message': 'Authentication token not found.'};
    }

    final uri = Uri.parse('$_backendUrl/$endpoint');
    http.Response response;
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      if (method == 'GET') {
        response = await http.get(uri, headers: headers);
      } else if (method == 'POST') {
        response = await http.post(uri, headers: headers, body: jsonEncode(body));
      } else if (method == 'PUT') {
        response = await http.put(uri, headers: headers, body: jsonEncode(body));
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers);
      } else {
        return {'success': false, 'message': 'Unsupported HTTP method: $method'};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        final errorData = json.decode(response.body);
        return {'success': false, 'message': errorData['error'] ?? 'Failed to fetch data: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error or failed to connect: $e'};
    }
  }
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    String? role,
    String? saccoName,
    String? saccoOwner,
    String? driverLicenseNumber,
    int? sacco_id,
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

         if (sacco_id != null) {
          body['sacco_id'] = sacco_id;
        }
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String? responseRole = responseBody['user']?['role'];
        final String? token = responseBody['token'];
        final int? saccoId = responseBody['user']?['sacco_id']; // Extract sacco_id from response

        if (token != null) {
          await TokenStorage.saveToken(token);
        }
        if (saccoId != null) {
          await TokenStorage.saveSaccoId(saccoId);
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
        final int? saccoId = responseBody['user']?['sacco_id']; // Extract sacco_id from response

        if (token != null) {
          await TokenStorage.saveToken(token);
        }
        if (saccoId != null) {
          await TokenStorage.saveSaccoId(saccoId);
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

  // Logout method
  static Future<void> logout() async {
    await TokenStorage.clearAllAuthData(); // Clear token and sacco_id
    // Optionally navigate to login screen after logout
  }

  // Moved _authenticatedFetch to AuthService as it uses backendUrl and token
  // This makes it reusable across different services.
  static Future<Map<String, dynamic>> authenticatedFetch(String endpoint, {String method = 'GET', Map<String, dynamic>? body}) {
    return _authenticatedFetch(endpoint, method: method, body: body);
  }
}