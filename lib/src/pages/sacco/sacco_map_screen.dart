import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'dart:convert'; // For JSON decoding (if mock data is used internally)

import 'package:flutter_map/flutter_map.dart'; // Import flutter_map
import 'package:latlong2/latlong.dart'; // Import LatLng
import 'package:latlong2/latlong.dart' as latlong; // Alias for Distance calculation

// Import your models
import 'package:ma3_app/src/models/vehicle.dart'; // Contains both Vehicle (for map) and ManagementVehicle
import 'package:ma3_app/src/models/route_data.dart'; // Contains RouteData and Stage

// Import the new Sacco service
import 'package:ma3_app/src/services/sacco_services.dart'; // Corrected import to sacco_service.dart

class SaccoMapScreen extends StatefulWidget {
  const SaccoMapScreen({super.key});

  @override
  State<SaccoMapScreen> createState() => _SaccoMapScreenState();
}

class _SaccoMapScreenState extends State<SaccoMapScreen> with SingleTickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _animationController;

  List<Vehicle> _vehiclesOnMap = []; // Vehicles with LatLng for map display
  RouteData? _assignedRoute; // The route assigned to the Sacco's vehicles
  List<LatLng> _routePolylinePoints = []; // Points to draw the route
  List<double> _segmentLengths = []; // Lengths of each segment for path animation
  double _totalRouteLength = 0.0;

  bool _isLoading = true;
  String _errorMessage = '';

  // Mock API response for a route (replace with actual route fetching if available)
  final String _mockRouteApiResponse = '''
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
    _mapController = MapController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30), // Duration for one full route cycle
    )..addListener(() {
        setState(() {
          _updateVehiclePositions(); // Update vehicle positions on each animation tick
        });
      })
      ..repeat(reverse: false); // Repeat animation continuously

    _loadSaccoMapData(); // Load vehicles and route data
  }

  Future<void> _loadSaccoMapData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Fetch Sacco's Vehicles
      final List<ManagementVehicle> fetchedVehicles = await SaccoService.fetchMyVehicles();

      // Convert ManagementVehicle to Vehicle for map display
      _vehiclesOnMap = fetchedVehicles.map((mv) => Vehicle(
        id: mv.id,
        // For now, assign a default position. In a real app, this would come from live tracking.
        position: LatLng(0, 0), // Will be updated by animation
        color: Colors.blue, // Default color, you might assign based on vehicle type
        icon: Icons.directions_bus, // Default icon
      )).toList();

      // 2. Load the Route Data (mocked for now)
      // In a real app, you'd fetch a route based on a vehicle's assigned route ID
      final Map<String, dynamic> jsonResponse = json.decode(_mockRouteApiResponse);
      if (jsonResponse.containsKey('error')) {
        _errorMessage = 'API Error: ${jsonResponse['error']}';
        _showSnackBar(_errorMessage, isError: true);
        return;
      }
      final routeJson = jsonResponse['route'];
      _assignedRoute = RouteData.fromJson(routeJson);

      _routePolylinePoints = _assignedRoute!.stages.map((s) => s.toLatLng()).toList();

      // Calculate segment lengths for smooth animation
      _segmentLengths = [];
      _totalRouteLength = 0.0;
      if (_routePolylinePoints.length > 1) {
        for (int i = 0; i < _routePolylinePoints.length - 1; i++) {
          final p1 = _routePolylinePoints[i];
          final p2 = _routePolylinePoints[i + 1];
          final distance = const latlong.Distance().as(
            latlong.LengthUnit.Meter,
            p1,
            p2,
          );
          _segmentLengths.add(distance);
          _totalRouteLength += distance;
        }
      }

      // Initialize vehicle positions to the start of the route
      if (_vehiclesOnMap.isNotEmpty && _routePolylinePoints.isNotEmpty) {
        for (var vehicle in _vehiclesOnMap) {
          vehicle.position = _routePolylinePoints.first;
        }
      }

      // FIX: Defer fitBounds call to ensure MapController is fully initialized
      if (_routePolylinePoints.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // FIX: Removed hasListeners check, just check mounted
          if (mounted) {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(_routePolylinePoints),
                padding: const EdgeInsets.all(50.0),
              ),
            );
          }
        });
      }

    } catch (e) {
      _errorMessage = 'Error loading map data: $e';
      _showSnackBar(_errorMessage, isError: true);
      print('Error loading sacco map data: $e'); // For debugging
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // This function updates vehicle positions along the loaded route
  void _updateVehiclePositions() {
    if (_routePolylinePoints.isEmpty || _totalRouteLength == 0 || _vehiclesOnMap.isEmpty) return;

    final double animatedDistance = _totalRouteLength * _animationController.value;

    double currentDistance = 0.0;
    LatLng? newPosition;

    for (int i = 0; i < _routePolylinePoints.length - 1; i++) {
      final segmentStart = _routePolylinePoints[i];
      final segmentEnd = _routePolylinePoints[i + 1];
      final segmentLength = _segmentLengths[i];

      if (animatedDistance >= currentDistance && animatedDistance <= currentDistance + segmentLength) {
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
      newPosition = _routePolylinePoints.last;
    }

    if (newPosition != null) {
      // Update all vehicles to the same position for this animation cycle.
      // In a real system, each vehicle would have its own actual location.
      for (var vehicle in _vehiclesOnMap) {
        vehicle.position = newPosition;
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red),
              SizedBox(height: 10),
              Text(
                'Error: $_errorMessage',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadSaccoMapData, // Retry loading
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _routePolylinePoints.isNotEmpty
            ? _routePolylinePoints.first // Center on start of route
            : const LatLng(-1.286389, 36.817223), // Default Nairobi CBD
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
        // Draw the route polyline
        if (_routePolylinePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePolylinePoints,
                color: Colors.teal, // Sacco theme color
                strokeWidth: 5.0,
                // FIX: Corrected deprecated Color.red/green/blue access
                borderColor: Colors.teal.withOpacity(0.5),
                borderStrokeWidth: 2.0,
              ),
            ],
          ),
        // Draw markers for stages (waypoints)
        MarkerLayer(
          markers: [
            ...(_assignedRoute?.stages.map((stage) {
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
            ..._vehiclesOnMap.map((vehicle) {
              return Marker(
                point: vehicle.position,
                width: 40.0,
                height: 40.0,
                rotate: true, // Allow marker to rotate with vehicle direction (more advanced)
                child: Icon(
                  vehicle.icon, // Use the icon from the Vehicle object
                  color: vehicle.color, // Use the color from the Vehicle object
                  size: 30.0,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController.dispose(); // Dispose map controller
    super.dispose();
  }
}