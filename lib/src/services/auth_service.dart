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
        if (responseRole == 'driver') { // <--- NEW: Save driver ID on driver signup
          final int? driverId = responseBody['user']?['driver']?['ID'];
          if (driverId != null) {
            await TokenStorage.saveDriverId(driverId);
          }
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
         if (role == 'driver') { // <--- NEW: Save driver ID on driver login
          final int? driverId = responseBody['user']?['driver']?['ID'];
          if (driverId != null) {
            await TokenStorage.saveDriverId(driverId);
          }
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
   Future<Map<String, dynamic>> getMyProfile() async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final response = await http.get(
      Uri.parse('$_backendUrl/api/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      // Decode the response body and return the 'user' map
      return json.decode(response.body)['user'];
    } else {
      // Handle API errors and provide a descriptive message
      final errorBody = json.decode(response.body);
      throw Exception('Failed to load profile: ${errorBody['error'] ?? response.statusCode}');
    }
  }

  /// Updates the current authenticated user's profile details.
  ///
  /// [data] is a map containing the fields to be updated.
  /// Throws an [Exception] if the token is not found or the API call fails.
  Future<Map<String, dynamic>> updateUserDetails(Map<String, dynamic> data) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final response = await http.patch( // Using PATCH for partial updates
      Uri.parse('$_backendUrl/api/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      // Decode the response body and return the updated 'user' map
      return json.decode(response.body)['user'];
    } else {
      // Handle API errors
      final errorBody = json.decode(response.body);
      throw Exception('Failed to update profile: ${errorBody['error'] ?? response.statusCode}');
    }
  }

  /// Changes the current authenticated user's password.
  ///
  /// [oldPassword] is the current password for verification.
  /// [newPassword] is the new password.
  /// Throws an [Exception] if the token is not found or the API call fails.
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    final response = await http.put( // Using PUT for password change
      Uri.parse('$_backendUrl/api/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      // Password changed successfully, no specific data to return
      return;
    } else {
      // Handle API errors
      final errorBody = json.decode(response.body);
      throw Exception('Failed to change password: ${errorBody['error'] ?? response.statusCode}');
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