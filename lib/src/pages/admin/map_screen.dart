//import 'dart:math';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'dart:async'; // Import for Timer
import '../../widgets/cartoon_map_painter.dart';
import '../../models/route_data.dart';
import 'package:flutter_map/flutter_map.dart'; // Import flutter_map
import 'package:latlong2/latlong.dart'; // Import LatLng

// --- Vehicle Model ---
class Vehicle {
  final String id;
  LatLng position; // Current position on the map (latitude, longitude)
  final Color color;
  final IconData icon; // For representing the vehicle visually
  // You can add more properties like speed, destination, etc.

  Vehicle({
    required this.id,
    required this.position,
    required this.color,
    this.icon = Icons.directions_car, // Default car icon
  });
}

// --- Map Screen with Debounce and Flutter Map ---
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _currentSearchTerm = '';

  late AnimationController _animationController;
  List<Vehicle> _vehicles = [];
  RouteData? _currentRoute; // To hold the parsed route data
  List<LatLng> _routePolylinePoints = []; // Points to draw the route
  List<double> _segmentLengths = []; // Lengths of each segment for path animation
  double _totalRouteLength = 0.0;

  // Mock API response (This would ideally be fetched from your backend)
  final String _mockApiResponse = '''
{
    "length": 7895.237178232105,
    "route": {
        "ID": 1,
        "CreatedAt": "2025-05-27T20:50:22.822423+03:00",
        "UpdatedAt": "2025-05-27T20:50:22.822423+03:00",
        "DeletedAt": null,
        "name": "Kiambu–CBD Parliament",
        "description": "Main commuter route from Kiambu Town to the CBD near Parliament",
        "sacco_id": 1,
        "geometry": "0102000020E610000002000000545227A089684240713D0AD7A370F3BF462575029A684240BE30992A1895F4BF",
        "stages": [
            {
                "ID": 1,
                "CreatedAt": "2025-05-27T20:50:22.823448+03:00",
                "UpdatedAt": "2025-05-27T20:50:22.823448+03:00",
                "DeletedAt": null,
                "name": "Kiambu Town Center",
                "seq": 1,
                "lat": -1.2149,
                "lng": 36.8168,
                "route_id": 1
            },
            {
                "ID": 2,
                "CreatedAt": "2025-05-27T20:50:22.823448+03:00",
                "UpdatedAt": "2025-05-27T20:50:22.823448+03:00",
                "DeletedAt": null,
                "name": "Thika Road Mall",
                "seq": 2,
                "lat": -1.255,
                "lng": 36.83,
                "route_id": 1
            },
            {
                "ID": 3,
                "CreatedAt": "2025-05-27T20:50:22.823448+03:00",
                "UpdatedAt": "2025-05-27T20:50:22.823448+03:00",
                "DeletedAt": null,
                "name": "Garden City",
                "seq": 3,
                "lat": -1.287,
                "lng": 36.831,
                "route_id": 1
            },
            {
                "ID": 4,
                "CreatedAt": "2025-05-27T20:50:22.823448+03:00",
                "UpdatedAt": "2025-05-27T20:50:22.823448+03:00",
                "DeletedAt": null,
                "name": "Parliament Roundabout",
                "seq": 4,
                "lat": -1.2864,
                "lng": 36.8172,
                "route_id": 1
            }
        ]
    }
}
  ''';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // Longer duration for route animation
    )..addListener(() {
        setState(() {
          _updateVehiclePositions(); // Update vehicle positions on each animation tick
        });
      })
      ..repeat(reverse: false); // Repeat animation continuously

    _loadRouteData(); // Load the mock route data
  }

  void _loadRouteData() {
    try {
      final Map<String, dynamic> jsonResponse = json.decode(_mockApiResponse);
      // Check for an 'error' key at the top level
      if (jsonResponse.containsKey('error')) {
        print('API Error: ${jsonResponse['error']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading route: ${jsonResponse['error']}')),
        );
        return;
      }
      final routeJson = jsonResponse['route'];
      _currentRoute = RouteData.fromJson(routeJson);

      // Populate polyline points from stages
      _routePolylinePoints = _currentRoute!.stages.map((s) => s.toLatLng()).toList();

      // Calculate segment lengths for smooth animation along the route
      _segmentLengths = [];
      _totalRouteLength = 0.0;
      if (_routePolylinePoints.length > 1) {
        for (int i = 0; i < _routePolylinePoints.length - 1; i++) {
          final p1 = _routePolylinePoints[i];
          final p2 = _routePolylinePoints[i + 1];
          // Using latlong2's Distance() for precise distance calculation
          final distance = const latlong.Distance().as(
            latlong.LengthUnit.Meter,
            p1,
            p2,
          );
          _segmentLengths.add(distance);
          _totalRouteLength += distance;
        }
      }

      // Initialize vehicles at the start of the loaded route
      _vehicles = [
        Vehicle(
          id: 'matatu1',
          position: _routePolylinePoints.first,
          color: Colors.blue,
        ),
        Vehicle(
          id: 'matatu2',
          position: _routePolylinePoints.first,
          color: Colors.green,
          icon: Icons.local_taxi,
        ),
      ];

      // Optionally, center the map on the route
      // mapController.fitBounds(LatLngBounds.fromPoints(_routePolylinePoints));
    } catch (e) {
      print('Error parsing route data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load route data: $e')),
      );
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty && _searchController.text != _currentSearchTerm) {
        _currentSearchTerm = _searchController.text;
        _performSearch(_currentSearchTerm);
      }
    });
  }

  void _performSearch(String query) {
    // Avoid print in production code, consider a logging framework.
    print('Simulating search for: $query');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Searching for route: "$query" on map!')),
    );
    // In a real app, you'd use a geocoding API here (e.g., OpenStreetMap Nominatim)
    // to convert `query` to LatLng and then center the map or highlight a route.
  }

  // This function updates vehicle positions along the loaded route
  void _updateVehiclePositions() {
    if (_routePolylinePoints.isEmpty || _totalRouteLength == 0) return;

    final double animatedDistance = _totalRouteLength * _animationController.value;

    double currentDistance = 0.0;
    LatLng? newPosition;

    for (int i = 0; i < _routePolylinePoints.length - 1; i++) {
      final segmentStart = _routePolylinePoints[i];
      final segmentEnd = _routePolylinePoints[i + 1];
      final segmentLength = _segmentLengths[i];

      if (animatedDistance >= currentDistance && animatedDistance <= currentDistance + segmentLength) {
        // Vehicle is on this segment
        final double segmentProgress = (animatedDistance - currentDistance) / segmentLength;
        newPosition = LatLng(
          segmentStart.latitude + (segmentEnd.latitude - segmentStart.latitude) * segmentProgress,
          segmentStart.longitude + (segmentEnd.longitude - segmentStart.longitude) * segmentProgress,
        );
        break;
      }
      currentDistance += segmentLength;
    }

    if (newPosition == null && _animationController.value == 1.0) {
      // Ensure vehicle reaches the very end if animation completes
      newPosition = _routePolylinePoints.last;
    }

    if (newPosition != null) {
      for (var vehicle in _vehicles) {
        // Assign the same position to all vehicles for simplicity in this example
        // In a real app, each vehicle would have its own animation/route
        vehicle.position = newPosition;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Route',
              hintText: 'e.g., Kiambu to CBD Parliament',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _currentSearchTerm = '';
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            ),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              _performSearch(value);
            },
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              // Center the map on the starting point of the route, or a default if no route
              initialCenter: _routePolylinePoints.isNotEmpty
                  ? _routePolylinePoints.first
                  : LatLng(-1.286389, 36.817223), // Nairobi CBD
              initialZoom: 12.0, // Zoom level to see the route
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'], // For CartoDB tiles
                userAgentPackageName: 'com.example.ma3_app',
                // FIX: Added retinaMode to resolve the warning
                retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
              ),
              // Draw the route polyline
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePolylinePoints,
                    color: Colors.blueAccent,
                    strokeWidth: 5.0,
                    // FIX: Deprecated withOpacity, use Color.fromARGB or similar
                    borderColor: Color.fromARGB((255 * 0.5).round(), Colors.blue.red, Colors.blue.green, Colors.blue.blue),
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),
              // Draw markers for stages (waypoints)
              MarkerLayer(
                markers: [
                  ...(_currentRoute?.stages.map((stage) {
                        return Marker(
                          point: stage.toLatLng(),
                          width: 80.0,
                          height: 80.0,
                          child: Column(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.purple,
                                size: 30.0,
                              ),
                              Flexible(
                                child: Text(
                                  stage.name,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 2.0,
                                        color: Colors.white,
                                        offset: Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }) ??
                      []),
                  // Markers for vehicles
                  ..._vehicles.map((vehicle) {
                    return Marker(
                      point: vehicle.position,
                      width: 40.0,
                      height: 40.0,
                      rotate: true, // Allow marker to rotate with vehicle direction (more advanced)
                      child: Transform.rotate(
                        // Example: make vehicle face direction
                        angle: _getVehicleRotationAngle(
                          vehicle.position,
                        ), // Implement this
                        child: Icon(
                          vehicle.icon,
                          color: vehicle.color,
                          size: 30.0,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Placeholder for getting vehicle rotation angle (needs more logic)
  double _getVehicleRotationAngle(LatLng currentPosition) {
    // This is a simplified placeholder.
    // In a real scenario, you would calculate the bearing between
    // the current point and the next point on the route.
    // For now, it returns 0, meaning no rotation.
    return 0;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}
