// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ma3_app/src/models/vehicle.dart'; // Adjust path if necessary
//import 'package:shared_preferences/shared_preferences.dart'; // To get the token
import 'package:ma3_app/src/services/token_storage.dart';
class DriverService {
  static final String? _baseUrl = dotenv.env['BACKEND_URL'];

  // Helper to get JWT token from TokenStorage and prepare headers
  Future<Map<String, String>> _getHeaders() async {
    if (_baseUrl == null) {
      throw Exception('Backend URL is not configured in .env file.');
    }

    // --- MODIFIED: Use TokenStorage to get the token ---
    final token = await TokenStorage.getToken();

    if (token == null) {
      // This exception should ideally be caught higher up to trigger a re-login flow
      throw Exception('Authentication token not found. Please log in.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Helper for authenticated GET requests
  Future<Map<String, dynamic>> _authenticatedFetch(String endpoint) async {
    if (_baseUrl == null) {
      throw Exception('Backend URL not configured.');
    }

    try {
      final url = Uri.parse('$_baseUrl/$endpoint');
      final headers = await _getHeaders(); // Get token and prepare headers

      final response = await http.get(
        url,
        headers: headers,
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody; // Return the raw response body
      } else if (response.statusCode == 401) {
        // --- MODIFIED: Use TokenStorage to delete the token ---
        await TokenStorage.deleteToken(); // Clear invalid token
        // Re-throw to be caught by the calling widget (e.g., MapScreen)
        throw Exception('Unauthorized: ${responseBody['error'] ?? 'Please log in again.'}');
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      print('API Fetch Error: $e'); // Log the error for debugging
      rethrow; // Re-throw to be caught by the calling widget
    }
  }

  // Helper for authenticated POST/PATCH requests
  Future<Map<String, dynamic>> _authenticatedMutate(String endpoint, String method, Map<String, dynamic> body) async {
    if (_baseUrl == null) {
      throw Exception('Backend URL not configured.');
    }

    try {
      final url = Uri.parse('$_baseUrl/$endpoint');
      final headers = await _getHeaders();

      http.Response response;
      if (method == 'POST') {
        response = await http.post(url, headers: headers, body: jsonEncode(body));
      } else if (method == 'PATCH') {
        response = await http.patch(url, headers: headers, body: jsonEncode(body));
      } else {
        throw Exception('Unsupported HTTP method: $method');
      }

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else if (response.statusCode == 401) {
        // --- MODIFIED: Use TokenStorage to delete the token ---
        await TokenStorage.deleteToken();
        throw Exception('Unauthorized: ${responseBody['error'] ?? 'Please log in again.'}');
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to complete operation: ${response.statusCode}');
      }
    } catch (e) {
      print('API Mutate Error: $e'); // Log the error for debugging
      rethrow;
    }
  }

 // --- MODIFIED: Fetch Driver Vehicle using stored driverId ---
  Future<Vehicle?> fetchDriverVehicle() async {
    try {
      final int? driverId = await TokenStorage.getDriverId();
      if (driverId == null) {
        throw Exception('Driver ID not found. Please log in again.');
      }

      // --- CRITICAL: Your backend needs an endpoint like this:
      // GET /api/vehicles/driver/:driverId
      // This will fetch a vehicle associated with the given driver ID.
      // Make sure your Go backend implements this.
      final responseBody = await _authenticatedFetch('driver/vehicles/driver/$driverId');

      if (responseBody['vehicle'] != null) {
        return Vehicle.fromJson(responseBody['vehicle']);
      }
      return null;
    } catch (e) {
      print('Error in fetchDriverVehicle: $e');
      rethrow;
    }
  }


  Future<bool> updateVehicleServiceStatus(int vehicleId, bool inService) async {
    try {
      await _authenticatedMutate(
        'driver/vehicles/$vehicleId',
        'PATCH',
        {'in_service': inService},
      );
      return true;
    } catch (e) {
      print('Error in updateVehicleServiceStatus: $e');
      rethrow;
    }
  }
}
