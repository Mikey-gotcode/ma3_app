import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ma3_app/src/services/token_storage.dart'; // Ensure correct import path
import 'package:ma3_app/src/services/auth_service.dart'; 
import 'package:ma3_app/src/models/vehicle.dart'; // Assuming ManagementVehicle is here
import 'package:ma3_app/src/models/driver.dart';
import 'package:ma3_app/src/models/route_data.dart';

class SaccoService {
  static final String? _backendUrl = dotenv.env['BACKEND_URL'];

  // Helper for authenticated GET requests
  static Future<Map<String, dynamic>> _authenticatedFetch(String endpoint) async {
    if (_backendUrl == null) {
      return {'success': false, 'message': 'Backend URL not configured.'};
    }

    try {
      final url = Uri.parse('$_backendUrl/$endpoint');
      final token = await TokenStorage.getToken();

      if (token == null) {
        return {'success': false, 'message': 'Authentication token not found. Please log in.'};
      }

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        url,
        headers: headers,
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Assuming GetMyVehicles returns {"vehicles": [...]} or {"data": [...]}
        return {'success': true, 'data': responseBody['data'] ?? responseBody['routes'] ?? responseBody['drivers'] ?? responseBody['vehicles']};
      } else if (response.statusCode == 401) {
        await TokenStorage.deleteToken(); // Clear invalid token
        return {'success': false, 'message': 'Unauthorized: ${responseBody['error'] ?? 'Please log in again.'}'};
      } else {
        return {'success': false, 'message': responseBody['error'] ?? 'Failed to fetch data.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  // Helper for authenticated POST/PATCH requests
  static Future<Map<String, dynamic>> _authenticatedMutate(String endpoint, String method, Map<String, dynamic> body) async {
    if (_backendUrl == null) {
      return {'success': false, 'message': 'Backend URL not configured.'};
    }

    try {
      final url = Uri.parse('$_backendUrl/$endpoint');
      final token = await TokenStorage.getToken();

      if (token == null) {
        return {'success': false, 'message': 'Authentication token not found. Please log in.'};
      }

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      http.Response response;
      if (method == 'POST') {
        response = await http.post(url, headers: headers, body: jsonEncode(body));
      } else if (method == 'PATCH') {
        response = await http.patch(url, headers: headers, body: jsonEncode(body));
      } else {
        return {'success': false, 'message': 'Unsupported HTTP method: $method'};
      }

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) { // Success status codes (2xx)
        return {'success': true, 'message': responseBody['message'] ?? 'Operation successful!', 'data': responseBody};
      } else if (response.statusCode == 401) {
        await TokenStorage.deleteToken();
        return {'success': false, 'message': 'Unauthorized: ${responseBody['error'] ?? 'Please log in again.'}'};
      } else {
        return {'success': false, 'message': responseBody['error'] ?? 'Failed to complete operation.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

    // Create a new vehicle
   static Future<Map<String, dynamic>> createVehicle({
    required String vehicleNo,
    required String vehicleRegistration,
    required int saccoId,
    required int driverId,
    required int routeId,
  }) async {
    if (_backendUrl == null) {
      return {'success': false, 'message': 'Backend URL not configured.'};
    }

    try {
      // This endpoint is specified as /sacco/vehicles, meaning it expects a Sacco's token.
      // Assuming the Admin's token has the necessary permissions to call this endpoint.
      final url = Uri.parse('$_backendUrl/sacco/vehicle');
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
        'sacco_id':saccoId,
        'driver_id': driverId,
        'route_id': routeId,
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



  // Fetches vehicles belonging to the authenticated Sacco
  static Future<List<ManagementVehicle>> fetchMyVehicles() async {
    final result = await _authenticatedFetch('sacco/vehicles');
    if (result['success'] && result['data'] is List) {
      return (result['data'] as List).map((json) => ManagementVehicle.fromJson(json)).toList();
    }
    return [];
  }

  // Fetches drivers associated with the authenticated Sacco
  static Future<List<Driver>> fetchMyDrivers() async {
    final result = await _authenticatedFetch('sacco/drivers');
    if (result['success'] && result['data'] is List) {
      return (result['data'] as List).map((json) => Driver.fromJson(json)).toList();
    }
    return [];
  }

  // Fetches routes associated with the authenticated Sacco
  static Future<List<RouteData>> fetchMyRoutes() async {
    final result = await _authenticatedFetch('sacco/routes');
    if (result['success'] && result['data'] is List) {
      return (result['data'] as List).map((json) => RouteData.fromJson(json)).toList();
    }
    return [];
  }


  // Fetches drivers associated with the authenticated Sacco
  static Future<List<Driver>> fetchDriversBySacco() async {
    final int? saccoId = await TokenStorage.getSaccoId();

    if (saccoId == null) {
      print('Error: Sacco ID not found for the authenticated user.');
      // You might want to show a SnackBar or throw an exception here
      return [];
    }

    // Construct the endpoint with the sacco_id as a query parameter
    final String endpoint = 'sacco/drivers/$saccoId';

    // Use the authenticatedFetch from AuthService
    final result = await AuthService.authenticatedFetch(endpoint);

    if (result['success'] && result['data'] is Map && result['data']['data'] is List) {
      return (result['data']['data'] as List).map((json) => Driver.fromJson(json)).toList();
    } else if (result['success'] && result['data'] is List) {
      // Fallback if the 'data' key nesting is not present
      // This is less likely if your backend always wraps in 'data'
      return (result['data'] as List).map((json) => Driver.fromJson(json)).toList();
    }
    print('Failed to fetch drivers: ${result['message']}');
    return [];
  }


  // Fetches drivers associated with the authenticated Sacco
  static Future<List<RouteData>> fetchRoutesBySacco() async {
    final int? saccoId = await TokenStorage.getSaccoId();

    if (saccoId == null) {
      print('Error: Sacco ID not found for the authenticated user.');
      // You might want to show a SnackBar or throw an exception here
      return [];
    }

    // Construct the endpoint with the sacco_id as a query parameter
    final String endpoint = 'sacco/routes/$saccoId';

    // Use the authenticatedFetch from AuthService
    final result = await AuthService.authenticatedFetch(endpoint);

    if (result['success'] && result['data'] is Map && result['data']['routes'] is List) {
      return (result['data']['routes'] as List).map((json) => RouteData.fromJson(json)).toList();
    } else if (result['success'] && result['data'] is List) {
      // Fallback if the 'data' key nesting is not present
      // This is less likely if your backend always wraps in 'data'
      return (result['data'] as List).map((json) => RouteData.fromJson(json)).toList();
    }
    print('Failed to fetch drivers: ${result['message']}');
    return [];
  }

  
// NEW METHOD: Fetches vehicles associated with a specific Sacco
  static Future<List<Vehicle>> fetchVehiclesBySacco() async {
    final int? saccoId = await TokenStorage.getSaccoId();

    if (saccoId == null) {
      print('Error: Sacco ID not found for the authenticated user.');
      return [];
    }

    // Construct the endpoint with sacco_id as a PATH parameter.
    // This assumes a backend route like: sacco.GET("/vehicles/:id", controllers.ListVehiclesBySacco)
    // IMPORTANT: Your current `vehicle_controller.go` does NOT have a `ListVehiclesBySacco`
    // that filters by path parameter. It has `GetMyVehicles` (filters by authenticated user's Sacco)
    // and `ListVehicles` (no filter). You will need to add/modify a backend endpoint
    // to support this client-side call pattern if you intend to filter vehicles by an arbitrary Sacco ID.
    final String endpoint = 'sacco/vehicles/$saccoId'; // Assuming a backend route similar to /sacco/drivers/:id

    // Use the authenticatedFetch from AuthService
    final result = await AuthService.authenticatedFetch(endpoint);

    if (result['success'] && result['data'] is List) {
      // Assuming the backend returns a list of vehicle objects directly under the 'data' key
      return (result['data'] as List).map((json) => Vehicle.fromJson(json)).toList();
    } else if (result['success'] && result['data'] is Map && result['data']['data'] is List) {
      // Fallback for backend responses that might wrap the list in {'data': {'data': [...]}}
      return (result['data']['data'] as List).map((json) => Vehicle.fromJson(json)).toList();
    }
    print('Failed to fetch vehicles: ${result['message'] ?? 'Unknown error'}');
    return [];
  }


  // --- You might also have other Sacco-related methods here ---
  // Example: Get a single route by ID
  static Future<RouteData?> getRouteById(int routeId) async {
    final String endpoint = 'sacco/route/$routeId'; // Assuming route is GET /sacco/route/:id
    final result = await AuthService.authenticatedFetch(endpoint);

    if (result['success'] && result['data'] is Map) {
      return RouteData.fromJson(result['data'] as Map<String, dynamic>);
    }
    print('Failed to fetch route $routeId: ${result['message'] ?? 'Unknown error'}');
    return null;
  }
  


  // Modified: Method for creating a Route (without stages)
  static Future<Map<String, dynamic>> createRoute({
    required String name,
    String? description,
    required String geometry, // Now required for initial route creation
  }) async {
    final int? saccoId = await TokenStorage.getSaccoId();
    return _authenticatedMutate(
      'sacco/routes', // POST /sacco/routes
      'POST',
      {
        'name': name,
        'sacco_id':saccoId,
        'description': description,
        'geometry': geometry,
      },
    );
  }

  // New: Method for adding or replacing stages for an existing route
  static Future<Map<String, dynamic>> addStagesToRoute({
    required int routeId,
    required List<Map<String, dynamic>> stages, // List of stage data
  }) async {
    return _authenticatedMutate(
      'sacco/routes/$routeId/stages', // PATCH /sacco/routes/:id/stages
      'PATCH',
      {
        'stages': stages,
      },
    );
  }
}