// lib/src/services/commuter_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart'; // For LatLng
import 'package:latlong2/latlong.dart' as math_latlong;
import 'package:ma3_app/src/models/vehicle.dart';
import 'package:ma3_app/src/models/route_data.dart';
import 'package:ma3_app/src/models/driver.dart'; 
import 'package:ma3_app/src/services/token_storage.dart'; // To get token

class CommuterService {
  static final String? _backendBaseUrl = dotenv.env['BACKEND_URL'];
  static final String? _orsApiKey = dotenv.env['ORS_API_KEY']; // Changed to ORS_API_KEY

  // Helper to get authenticated headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // --- Methods to fetch initial data (Vehicles and Routes) for ALL ---
  // These methods now fetch all vehicles/routes/drivers, not filtered by saccoId.
  // Your backend must expose corresponding endpoints that are accessible to the 'commuter' role.
  static Future<List<Vehicle>> fetchAllVehicles() async {
    if (_backendBaseUrl == null) {
      throw Exception('BACKEND_BASE_URL is not configured in .env');
    }

    final url = Uri.parse('$_backendBaseUrl/vehicles'); // Changed URL: removed /sacco/$saccoId
    final headers = await _getAuthHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => Vehicle.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load all vehicles: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to fetch all vehicles: $e');
    }
  }

  static Future<List<RouteData>> fetchAllRoutes() async {
    if (_backendBaseUrl == null) {
      throw Exception('BACKEND_BASE_URL is not configured in .env');
    }

    final url = Uri.parse('$_backendBaseUrl/routes'); // Changed URL: removed /sacco/$saccoId
    final headers = await _getAuthHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => RouteData.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load all routes: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to fetch all routes: $e');
    }
  }

  static Future<List<Driver>> fetchAllDrivers() async {
    if (_backendBaseUrl == null) {
      throw Exception('BACKEND_BASE_URL is not configured in .env');
    }

    final url = Uri.parse('$_backendBaseUrl/drivers'); // Changed URL: removed /sacco/$saccoId
    final headers = await _getAuthHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => Driver.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load all drivers: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to fetch all drivers: $e');
    }
  }

  // --- Methods for Location Search and Route Finding (Requires Backend/External API) ---

  /// Searches for places using OpenRouteService (ORS) Geocoding API.
  /// Returns a list of maps, each containing 'name', 'latitude', and 'longitude'.
  static Future<List<Map<String, dynamic>>> searchPlaces(String query, {LatLng? near}) async {
    if (query.isEmpty) return [];
    if (_orsApiKey == null || _orsApiKey!.isEmpty) {
      throw Exception('ORS_API_KEY is not configured in .env. Cannot perform location search.');
    }

    // Construct the ORS Geocoding API URL
    // Documentation: https://openrouteservice.org/dev/#/api-docs/geocode/search/get
    final Map<String, String> queryParams = {
      'api_key': _orsApiKey!,
      'text': query,
    };
    if (near != null) {
      // Add focus point for better results near a specific location
      queryParams['focus.point.lat'] = near.latitude.toString();
      queryParams['focus.point.lon'] = near.longitude.toString();
    }

    final uri = Uri.https('api.openrouteservice.org', '/geocode/search', queryParams);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];

        return features.map((feature) {
          final properties = feature['properties'] as Map<String, dynamic>;
          final geometry = feature['geometry'] as Map<String, dynamic>;
          final coordinates = geometry['coordinates'] as List<dynamic>; // [longitude, latitude]

          return {
            'name': properties['label'] ?? properties['name'] ?? 'Unknown Place',
            'latitude': coordinates[1] as double, // ORS returns [lon, lat]
            'longitude': coordinates[0] as double,
          };
        }).toList();
      } else {
        throw Exception('Failed to search places with ORS: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to ORS for place search: $e');
    }
  }

  // Placeholder for a route finding API that handles multi-leg routes
  // This method would typically call your backend to perform the 1-way, 2-way, 3-way logic.
  // The backend would then return the optimal route as a list of RouteData objects or polylines.
  static Future<List<RouteData>> findOptimalRoute(LatLng start, LatLng end) async {
    // This is a placeholder. Your backend needs to implement the complex route search logic.
    // It would take start/end coordinates and return the optimal route(s).
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay

    // Dummy response: Return a direct route if available, otherwise empty.
    final dummyRoutePoints = [
      start,
      math_latlong.LatLng((start.latitude + end.latitude) / 2, (start.longitude + end.longitude) / 2),
      end,
    ];

    final dummyRoute = RouteData(
      id: 999, // Dummy ID
      name: 'Direct Route from ${start.latitude.toStringAsFixed(2)},${start.longitude.toStringAsFixed(2)} to ${end.latitude.toStringAsFixed(2)},${end.longitude.toStringAsFixed(2)}',
      geometry: json.encode({
        'type': 'LineString',
        'coordinates': dummyRoutePoints.map((p) => [p.longitude, p.latitude]).toList(),
      }),
      stages: [], 
      description: "",//fix descrpition place ho
    );

    return [dummyRoute]; 

    // Real implementation (assuming backend endpoint /commuter/find-route):
    /*
    if (_backendBaseUrl == null) {
      throw Exception('BACKEND_BASE_URL is not configured in .env');
    }
    final url = Uri.parse('$_backendBaseUrl/commuter/find-route');
    final headers = await _getAuthHeaders();
    final body = json.encode({
      'start_lat': start.latitude,
      'start_lon': start.longitude,
      'end_lat': end.latitude,
      'end_lon': end.longitude,
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      List<dynamic> responseBody = json.decode(response.body);
      return responseBody.map((item) => RouteData.fromJson(item)).toList();
    } else {
      throw Exception('Failed to find optimal route: ${response.statusCode} - ${response.body}');
    }
    */
  }
}
