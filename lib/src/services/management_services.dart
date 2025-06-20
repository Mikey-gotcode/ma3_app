// lib/src/services/management_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './token_storage.dart';

// Assuming these models are defined in lib/src/models/
import 'package:ma3_app/src/models/sacco.dart';
import 'package:ma3_app/src/models/commuter.dart';
import 'package:ma3_app/src/models/driver.dart';
import 'package:ma3_app/src/models/vehicle.dart'; // Assuming ManagementVehicle is defined here

class ManagementService {
  static final String? _backendUrl = dotenv.env['BACKEND_URL'];

  static Future<Map<String, dynamic>> _fetchData(String endpoint) async {
    if (_backendUrl == null) {
      return {'success': false, 'message': 'Backend URL not configured.'};
    }

    try {
      final url = Uri.parse('$_backendUrl/$endpoint');
      final token = await TokenStorage.getToken(); // Retrieve the token

      Map<String, String> headers = {'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] =
            'Bearer $token'; // Add the Authorization header
      } else {
        // Optionally, handle cases where no token is found (e.g., user not logged in)
        // You might want to return an unauthorized error or redirect to login.
        return {
          'success': false,
          'message': 'Authentication token not found. Please log in.',
        };
      }

      final response = await http.get(
        url,
        headers: headers, // Use the updated headers
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Assuming the API returns a map with a 'data' key containing the list
        return {'success': true, 'data': responseBody['data'] ?? responseBody};
      } else if (response.statusCode == 401) {
        // Specific handling for unauthorized access (e.g., token expired or invalid)
        await TokenStorage.deleteToken(); // Clear invalid token
        return {
          'success': false,
          'message':
              'Unauthorized: ${responseBody['error'] ?? 'Please log in again.'}',
        };
      } else {
        return {
          'success': false,
          'message': responseBody['error'] ?? 'Failed to fetch data.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  static Future<List<Sacco>> fetchSaccos() async {
    final result = await _fetchData('admin/saccos');
    if (result['success'] && result['data'] is List) {
      return (result['data'] as List)
          .map((json) => Sacco.fromJson(json))
          .toList();
    }
    return [];
  }

  static Future<List<Commuter>> fetchCommuters() async {
    final result = await _fetchData('admin/commuters');
    if (result['success'] && result['data'] is List) {
      return (result['data'] as List)
          .map((json) => Commuter.fromJson(json))
          .toList();
    }
    return [];
  }

  static Future<List<Driver>> fetchDrivers() async {
    final result = await _fetchData('admin/drivers');
    if (result['success'] && result['data'] is List) {
      return (result['data'] as List)
          .map((json) => Driver.fromJson(json))
          .toList();
    }
    return [];
  }

  static Future<List<ManagementVehicle>> fetchVehicles() async {
    final result = await _fetchData('admin/vehicles');
    if (result['success'] && result['data'] is List) {
      return (result['data'] as List)
          .map((json) => ManagementVehicle.fromJson(json))
          .toList();
    }
    return [];
  }

  // New method for creating a vehicle (intended for Sacco role via backend, but Admin can use it too)
  static Future<Map<String, dynamic>> createVehicle({
    required String vehicleNo,
    required String vehicleRegistration,
 
  }) async {
    if (_backendUrl == null) {
      return {'success': false, 'message': 'Backend URL not configured.'};
    }

    try {
      // This endpoint is specified as /sacco/vehicles, meaning it expects a Sacco's token.
      // Assuming the Admin's token has the necessary permissions to call this endpoint.
      final url = Uri.parse('$_backendUrl/sacco/vehicles');
      final token = await TokenStorage.getToken();

      if (token == null) {
        return {'success': false, 'message': 'Authentication token not found. Please log in.'};
      }

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final Map<String, dynamic> body = {
        'vehicle_no': vehicleNo,
        'vehicle_registration': vehicleRegistration,
       
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) { // 201 Created is typical for successful POST
        return {'success': true, 'message': responseBody['message'] ?? 'Vehicle created successfully!', 'vehicle': responseBody['vehicle']};
      } else if (response.statusCode == 401) {
        await TokenStorage.deleteToken(); // Clear token if unauthorized
        return {'success': false, 'message': 'Unauthorized: ${responseBody['error'] ?? 'Please log in again.'}'};
      } else {
        return {'success': false, 'message': responseBody['error'] ?? 'Failed to create vehicle.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
}
