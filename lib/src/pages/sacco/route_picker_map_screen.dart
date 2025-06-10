// lib/src/pages/role_pages/sacco/route_picker_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert'; // For JSON encoding/decoding
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For accessing API key
import 'dart:async'; // For Timer debounce

class RoutePickerMapScreen extends StatefulWidget {
  const RoutePickerMapScreen({super.key});

  @override
  State<RoutePickerMapScreen> createState() => _RoutePickerMapScreenState();
}

class _RoutePickerMapScreenState extends State<RoutePickerMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _startLocationController = TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();

  LatLng? _startPoint;
  LatLng? _endPoint;
  String? _generatedGeometry;
  List<LatLng> _routePolylinePoints = []; // To store the actual routed polyline

  bool _isGeocodingLoading = false;
  bool _isRoutingLoading = false;

  Timer? _startDebounce; // Debounce timer for start location search
  Timer? _endDebounce;   // Debounce timer for end location search

  final String ? _orsApiKey = dotenv.env['ORS_API_KEY']; // Get from .env

  @override
  void initState() {
    super.initState();
    // Attach listeners for debounced search
    _startLocationController.addListener(() => _onSearchChanged(_startLocationController.text, true));
    _endLocationController.addListener(() => _onSearchChanged(_endLocationController.text, false));
  }

  // Debounce logic for text field changes
  void _onSearchChanged(String query, bool isStart) {
    // Cancel existing debounce timer
    if (isStart) {
      if (_startDebounce?.isActive ?? false) _startDebounce!.cancel();
    } else {
      if (_endDebounce?.isActive ?? false) _endDebounce!.cancel();
    }

    // Start a new debounce timer
    final Duration debounceDuration = const Duration(milliseconds: 700); // Increased to 700ms for better user experience

    if (isStart) {
      _startDebounce = Timer(debounceDuration, () {
        if (query.isNotEmpty) {
          _geocodeLocation(query, true);
        } else {
          // Clear points if text field is empty
          setState(() {
            _startPoint = null;
            _routePolylinePoints = [];
            _generatedGeometry = null;
          });
          _showSnackBar('Start location cleared.');
        }
      });
    } else {
      _endDebounce = Timer(debounceDuration, () {
        if (query.isNotEmpty) {
          _geocodeLocation(query, false);
        } else {
          // Clear points if text field is empty
          setState(() {
            _endPoint = null;
            _routePolylinePoints = [];
            _generatedGeometry = null;
          });
          _showSnackBar('End location cleared.');
        }
      });
    }
  }


  // Function to perform geocoding using OpenRouteService
  Future<LatLng?> _geocodeLocation(String locationName, bool isStart) async {
    if (locationName.isEmpty) {
      return null; // Already handled by debounce _onSearchChanged
    }
    if (_orsApiKey == 'YOUR_ORS_API_KEY' || _orsApiKey!.isEmpty) {
      _showSnackBar('OpenRouteService API Key is not configured in .env file. Please check your .env and pubspec.yaml.', isError: true);
      return null;
    }

    if (!mounted) return null; // Pre-check mounted to avoid setState on disposed object
    setState(() { _isGeocodingLoading = true; });
    _showSnackBar('Searching for "$locationName"...');

    final String url = 'https://api.openrouteservice.org/geocode/search?api_key=$_orsApiKey&text=$locationName';

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return null;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final List<dynamic> coordinates = data['features'][0]['geometry']['coordinates'];
          // ORS returns [longitude, latitude]
          final LatLng foundPoint = LatLng(coordinates[1], coordinates[0]);

          setState(() { // setState around point update for immediate UI reflection
            if (isStart) {
              _startPoint = foundPoint;
            } else {
              _endPoint = foundPoint;
            }
          });

          // Move map to the newly found point
          _mapController.move(foundPoint, _mapController.camera.zoom);

          // Only attempt to generate route if both points are now available
          if (_startPoint != null && _endPoint != null) {
            _showSnackBar('Locations found! Attempting to generate route...');
            await _getRouteGeometry(); // Automatically trigger routing
          } else {
            _showSnackBar('Location found! Now enter the other location.');
          }

          return foundPoint;
        } else {
          _showSnackBar('Location not found for "$locationName".', isError: true);
          return null;
        }
      } else {
        String errorMsg = 'Geocoding failed: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          errorMsg += ' - ${errorData['error']['message'] ?? response.body}';
        } catch (_) {
          errorMsg += ' - ${response.body}';
        }
        _showSnackBar(errorMsg, isError: true);
        return null;
      }
    } catch (e) {
      _showSnackBar('Error during geocoding: $e', isError: true);
      return null;
    } finally {
      if (mounted) setState(() { _isGeocodingLoading = false; });
    }
  }

  // Function to perform routing using OpenRouteService
  Future<void> _getRouteGeometry() async {
    if (_startPoint == null || _endPoint == null) {
      _showSnackBar('Both start and end locations are required to generate a route.', isError: true);
      return;
    }
    if (_orsApiKey == 'YOUR_ORS_API_KEY' || _orsApiKey!.isEmpty) {
      _showSnackBar('OpenRouteService API Key is not configured in .env file. Please check your .env and pubspec.yaml.', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isRoutingLoading = true;
      _routePolylinePoints = []; // Clear previous route
      _generatedGeometry = null; // Clear previous geometry
    });

    // ORS expects coordinates as [longitude, latitude]
    final String startCoords = '${_startPoint!.longitude},${_startPoint!.latitude}';
    final String endCoords = '${_endPoint!.longitude},${_endPoint!.latitude}';

    // Using 'driving-car' profile for road network.
    // This profile is generally suitable for major roadways.
    final String url = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsApiKey&start=$startCoords&end=$endCoords';

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final List<dynamic> coordinates = data['features'][0]['geometry']['coordinates'];

          _routePolylinePoints = coordinates.map<LatLng>((coord) {
            return LatLng(coord[1], coord[0]); // Convert [lng, lat] to LatLng
          }).toList();

          // Store the raw GeoJSON LineString for submission
          _generatedGeometry = jsonEncode(data['features'][0]['geometry']);

          _showSnackBar('Route generated successfully!');

          // Fit map to the generated route
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _routePolylinePoints.isNotEmpty) {
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(_routePolylinePoints),
                  padding: const EdgeInsets.all(50.0),
                ),
              );
            }
          });
        } else {
          _showSnackBar('No routable path found between selected locations. Try different points.', isError: true);
        }
      } else {
        // Handle non-200 responses, including 400 errors from ORS
        String errorMsg = 'Routing failed: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          // Attempt to extract ORS specific error message for more detail
          if (errorData['error'] != null && errorData['error']['message'] != null) {
            errorMsg += ' - ORS Error: ${errorData['error']['message']}';
          } else {
            errorMsg += ' - ${response.body}'; // Fallback to raw body
          }
        } catch (_) {
          errorMsg += ' - ${response.body}'; // Fallback if body is not valid JSON
        }
        _showSnackBar(errorMsg, isError: true);

        // If the problem is persistent 400, user might need to adjust their input
        // or the backend route profile. The current implementation already attempts
        // a route if points are set. "Force get" implicitly means:
        // 1. Ensure the API call is made (which it is, automatically after geocoding).
        // 2. Provide clear feedback if it fails.
        // 3. For a commuting app using major roads, 'driving-car' is usually sufficient.
        // If specific roads are problematic, ORS error messages would detail it.
      }
    } catch (e) {
      _showSnackBar('Error during routing: $e', isError: true);
    } finally {
      if (mounted) setState(() { _isRoutingLoading = false; });
    }
  }

  void _submitGeometry() {
    if (_generatedGeometry != null && _routePolylinePoints.isNotEmpty && !_isGeocodingLoading && !_isRoutingLoading) {
      Navigator.pop(context, _generatedGeometry); // Pop with the result
    } else if (_isGeocodingLoading || _isRoutingLoading) {
      _showSnackBar('Please wait for the route to finish generating.', isError: true);
    }
    else {
      _showSnackBar('Please generate a route first by searching for start and end locations.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide previous snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3), // Increased duration for readability
      ),
    );
  }

  @override
  void dispose() {
    _startDebounce?.cancel(); // Cancel debounce timers
    _endDebounce?.cancel();
    _startLocationController.dispose();
    _endLocationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Route on Map'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Pop without result
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _startLocationController,
                  decoration: InputDecoration(
                    labelText: 'Start Location',
                    // suffixIcon for geocoding loading only
                    suffixIcon: _isGeocodingLoading && _startLocationController.text.isNotEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                          )
                        : null, // Removed search icon as search is now debounced
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (text) => _onSearchChanged(text, true), // Debounced search
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _endLocationController,
                  decoration: InputDecoration(
                    labelText: 'End Location',
                    // suffixIcon for geocoding loading only
                    suffixIcon: _isGeocodingLoading && _endLocationController.text.isNotEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                          )
                        : null, // Removed search icon as search is now debounced
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (text) => _onSearchChanged(text, false), // Debounced search
                ),
                const SizedBox(height: 8),
                // Display routing loading indicator if _isRoutingLoading is true
                if (_startPoint != null && _endPoint != null && _isRoutingLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator.adaptive(),
                        SizedBox(width: 10),
                        Text('Generating route...'),
                      ],
                    ),
                  ),
                // Display generated geometry or prompt
                if (!_isRoutingLoading) // Only show geometry text if not loading route
                  Text(
                    _generatedGeometry != null
                        ? 'Generated GeoJSON (LineString): $_generatedGeometry'
                        : 'Type start and end locations to generate a route.',
                    style: TextStyle(fontSize: 12, color: _generatedGeometry != null ? Colors.green : Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _startPoint ?? const LatLng(-1.286389, 36.817223), // Default Nairobi CBD
                initialZoom: 12.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.ma3_app',
                  retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
                ),
                // Display the *routed* polyline from ORS
                if (_routePolylinePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePolylinePoints,
                        color: Colors.blue, // A color for the route
                        strokeWidth: 5.0,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_startPoint != null)
                      Marker(
                        point: _startPoint!,
                        width: 80.0,
                        height: 80.0,
                        child: Column(
                          children: [
                            Icon(Icons.location_on, color: Colors.green, size: 40),
                            Text('Start', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    if (_endPoint != null)
                      Marker(
                        point: _endPoint!,
                        width: 80.0,
                        height: 80.0,
                        child: Column(
                          children: [
                            Icon(Icons.location_on, color: Colors.red, size: 40),
                            Text('End', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatedGeometry != null && !_isGeocodingLoading && !_isRoutingLoading
                    ? _submitGeometry
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Submit Geometry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}