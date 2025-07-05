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
  // These methods now fetch all vehicles/routes/drivers from the new /commuter prefixed endpoints.
  // Your backend must expose corresponding endpoints that are accessible to the 'commuter' role.
  static Future<List<Vehicle>> fetchAllVehicles() async {
    if (_backendBaseUrl == null) {
      throw Exception('BACKEND_BASE_URL is not configured in .env');
    }

    // UPDATED URL to hit the new /commuter/vehicles endpoint
    final url = Uri.parse('$_backendBaseUrl/commuter/vehicles'); 
    final headers = await _getAuthHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // --- MODIFIED PARSING LOGIC HERE ---
        final Map<String, dynamic> responseBody = json.decode(response.body);
        // Assuming the list of vehicles is under a key like 'data' or 'vehicles'
        // Adjust 'data' to the actual key your backend uses if different.
        final List<dynamic> vehicleList = responseBody['data'] ?? responseBody['vehicles'] ?? []; 
        return vehicleList.map((dynamic item) => Vehicle.fromJson(item)).toList();
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

    // UPDATED URL to hit the new /commuter/routes endpoint
    final url = Uri.parse('$_backendBaseUrl/commuter/routes'); 
    final headers = await _getAuthHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // --- ADDED PARSING LOGIC HERE (similar to fetchAllVehicles) ---
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final List<dynamic> routeList = responseBody['data'] ?? responseBody['routes'] ?? []; 
        return routeList.map((dynamic item) => RouteData.fromJson(item)).toList();
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

    // UPDATED URL to hit the new /commuter/drivers endpoint
    final url = Uri.parse('$_backendBaseUrl/commuter/drivers'); 
    final headers = await _getAuthHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // --- ADDED PARSING LOGIC HERE (similar to fetchAllVehicles) ---
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final List<dynamic> driverList = responseBody['data'] ?? responseBody['drivers'] ?? []; 
        return driverList.map((dynamic item) => Driver.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load all drivers: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to fetch all drivers: $e');
    }
  }

  // --- Methods for Location Search and Route Finding (ORS and Backend) ---

  /// Searches for places using OpenRouteService (ORS) Geocoding API.
  /// Returns a list of maps, each containing 'name', 'latitude', and 'longitude'.
  static Future<List<Map<String, dynamic>>> searchPlaces(String query, {LatLng? near}) async {
    if (query.isEmpty) return [];
    if (_orsApiKey == null || _orsApiKey!.isEmpty) {
      throw Exception('ORS_API_KEY is not configured in .env. Cannot perform location search.');
    }

    // Construct the ORS Geocoding API URL
    final Map<String, String> queryParams = {
      'api_key': _orsApiKey!,
      'text': query,
    };
    if (near != null) {
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
 
  // --- NEW: Function to get route geometry from OpenRouteService ---
  // --- MODIFIED: Function to get route geometry from OpenRouteService ---
  static Future<String?> _getRouteGeometryFromORS(
      math_latlong.LatLng start, math_latlong.LatLng end) async {
    if (_orsApiKey == null || _orsApiKey!.isEmpty || _orsApiKey == 'YOUR_ORS_API_KEY') {
      print('Error: OpenRouteService API Key is not configured.');
      return null;
    }

    final String url = 'https://api.openrouteservice.org/v2/directions/driving-car/geojson'; // Base URL for POST

    final Map<String, dynamic> requestBody = {
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude]
      ],
      "radiuses": [-1, -1] // Optional: no radius constraint for start/end points
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': _orsApiKey!, // ORS API Key goes in the Authorization header
          'Content-Type': 'application/json',
          'Accept': 'application/json, application/geo+json, application/gpx+xml, application/polyline, application/json; charset=utf-8', // Added Accept header
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          return json.encode(data['features'][0]['geometry']);
        } else {
          print('No routable path found from ORS.');
          return null;
        }
      } else {
        String errorMsg = 'ORS Routing failed: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            errorMsg += ' - ORS Error: ${errorData['error']['message']}';
          } else {
            errorMsg += ' - ${response.body}';
          }
        } catch (_) {
          errorMsg += ' - ${response.body}';
        }
        print(errorMsg);
        return null;
      }
    } catch (e) {
      print('Error during ORS routing: $e');
      return null;
    }
  }


  // --- MODIFIED: findOptimalRoute to first query ORS then send to backend ---
  static Future<List<RouteData>> findOptimalRoute(
      math_latlong.LatLng start, math_latlong.LatLng end) async {
    if (_backendBaseUrl!.isEmpty) {
      throw Exception('BACKEND_BASE_URL is not configured');
    }

    // Step 1: Get optimal route geometry from OpenRouteService
    print('Attempting to get route geometry from ORS...');
    final String? orsGeometry = await _getRouteGeometryFromORS(start, end);

    if (orsGeometry == null) {
      throw Exception('Failed to generate an optimal route from OpenRouteService.');
    }
    print('Successfully got ORS geometry. Submitting to backend...');

    // Step 2: Submit the ORS generated geometry to your backend
    final url = Uri.parse('$_backendBaseUrl/commuter/routes/find-optimal');
    final headers = await _getAuthHeaders();
    final body = json.encode({
      'start_lat': start.latitude, // Still useful for context or fallback
      'start_lon': start.longitude,
      'end_lat': end.latitude,     // Still useful for context or fallback
      'end_lon': end.longitude,
      'optimal_geometry_geojson': orsGeometry, // NEW: Send the GeoJSON string
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
       final Map<String, dynamic> responseMap = json.decode(response.body);
        if (responseMap.containsKey('data') && responseMap['data'] is List) {
          List<dynamic> responseList = responseMap['data'];
          return responseList.map((item) => RouteData.fromJson(item)).toList();
        } else {
          // Handle cases where 'data' key is missing or not a List
          throw Exception('Backend response structure invalid: Missing "data" list.');
        }
      } else {
        String errorDetail = response.body;
        try {
          final errorJson = json.decode(response.body);
          if (errorJson['error'] != null) {
            errorDetail = errorJson['error'];
          }
        } catch (_) {
          // ignore parsing error
        }
        throw Exception(
            'Failed to find optimal route from backend: ${response.statusCode} - $errorDetail');
      }
    } catch (e) {
      throw Exception('Error connecting to backend for optimal route: $e');
    }
  }
}
