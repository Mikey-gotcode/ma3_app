import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'dart:convert'; // For JSON decoding

import 'package:flutter_map/flutter_map.dart'; // Provides MapController, TileLayer, Marker, Polyline, LatLng, LatLngBounds, MapOptions, CameraFit, InteractionOptions, InteractiveFlag
import 'package:latlong2/latlong.dart' as math_latlong; // Alias for Distance calculation and other latlong2 types to avoid conflict with flutter_map's LatLng

// Import your models
import 'package:ma3_app/src/models/vehicle.dart';
import 'package:ma3_app/src/models/route_data.dart';

// Import the Sacco service
import 'package:ma3_app/src/services/sacco_services.dart'; // Ensure this path is correct
import 'package:ma3_app/src/services/token_storage.dart'; // To get saccoId

// Helper class to store pre-calculated route animation info
class _RouteCalculatedInfo {
  final List<math_latlong.LatLng> polylinePoints; // Use LatLng from flutter_map
  final List<double> segmentLengths;
  final double totalRouteLength;

  _RouteCalculatedInfo({
    required this.polylinePoints,
    required this.segmentLengths,
    required this.totalRouteLength,
  });
}


class SaccoMapScreen extends StatefulWidget {
  const SaccoMapScreen({super.key});

  @override
  State<SaccoMapScreen> createState() => _SaccoMapScreenState();
}

class _SaccoMapScreenState extends State<SaccoMapScreen> with SingleTickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _animationController;

  List<Vehicle> _vehiclesOnMap = []; // All fetched vehicles
  List<RouteData> _allRoutesOnMap = []; // All fetched routes
  Map<int, RouteData> _routeIdToRouteData = {}; // Map to quickly find RouteData by ID
  Map<int, _RouteCalculatedInfo> _routeAnimationInfo = {}; // Pre-calculated animation data per route

  bool _isLoading = true;
  String _errorMessage = '';

  // Default center if no routes/vehicles are found (using flutter_map's LatLng)
  static const math_latlong.LatLng _defaultNairobiCenter = math_latlong.LatLng(-1.286389, 36.817223);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30), // Duration for one full route cycle (can be adjusted)
    )..addListener(() {
        if (mounted) {
          setState(() {
            _updateVehiclePositions(); // Update vehicle positions on each animation tick
          });
        }
      })
      ..repeat(reverse: false); // Repeat animation continuously

    _loadSaccoMapData(); // Load all necessary data
  }

  Future<void> _loadSaccoMapData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _vehiclesOnMap = [];
      _allRoutesOnMap = [];
      _routeIdToRouteData = {};
      _routeAnimationInfo = {};
    });

    try {
      final int? saccoId = await TokenStorage.getSaccoId();
      if (saccoId == null) {
        throw Exception('Sacco ID not found. Cannot fetch data.');
      }

      // 1. Fetch all Vehicles for the authenticated Sacco
      final List<Vehicle> fetchedVehicles = await SaccoService.fetchVehiclesBySacco();
      _vehiclesOnMap = fetchedVehicles;


      // 2. Fetch all Routes for the authenticated Sacco
      final List<RouteData> fetchedRoutes = await SaccoService.fetchRoutesBySacco();
      _allRoutesOnMap = fetchedRoutes;

      // Prepare lookup map and pre-calculate animation info for each route
      LatLngBounds? overallBounds; // Use LatLngBounds from flutter_map

      for (var route in _allRoutesOnMap) {
        _routeIdToRouteData[route.id] = route;

        List<math_latlong.LatLng> polylinePoints = []; // Use LatLng from flutter_map
        // Parse route geometry from GeoJSON string
        if (route.geometry.isNotEmpty) {
          try {
            final Map<String, dynamic> geoJson = json.decode(route.geometry);
            if (geoJson['type'] == 'LineString' && geoJson['coordinates'] is List) {
              polylinePoints = (geoJson['coordinates'] as List)
                  .map((coord) => math_latlong.LatLng(coord[1] as double, coord[0] as double)) // GeoJSON is [lng, lat]
                  .toList();
            } else {
              debugPrint('Warning: Route ID ${route.id} geometry is not a valid LineString GeoJSON. Falling back to stages.');
              polylinePoints = route.stages.map((s) => s.toLatLng()).toList(); // Fallback to stages
            }
          } catch (e) {
            debugPrint('Error parsing geometry for route ID ${route.id} as GeoJSON: $e. Falling back to stages.');
            polylinePoints = route.stages.map((s) => s.toLatLng()).toList(); // Fallback
          }
        } else {
          polylinePoints = route.stages.map((s) => s.toLatLng()).toList(); // Use stages if geometry is empty
        }

        List<double> segmentLengths = [];
        double totalRouteLength = 0.0;
        if (polylinePoints.length > 1) {
          for (int i = 0; i < polylinePoints.length - 1; i++) {
            final p1 = polylinePoints[i];
            final p2 = polylinePoints[i + 1];
            // Use math_latlong.Distance for calculations
            final distance = const math_latlong.Distance().as(
              math_latlong.LengthUnit.Meter,
              p1,
              p2,
            );
            segmentLengths.add(distance);
            totalRouteLength += distance;
          }
        }

        _routeAnimationInfo[route.id] = _RouteCalculatedInfo(
          polylinePoints: polylinePoints,
          segmentLengths: segmentLengths,
          totalRouteLength: totalRouteLength,
        );

        // Extend overall map bounds to include all routes
        if (polylinePoints.isNotEmpty) {
          final routeBounds = LatLngBounds.fromPoints(polylinePoints); // Use LatLngBounds from flutter_map
          if (overallBounds == null) {
            overallBounds = routeBounds;
          } else {
            overallBounds.extend(routeBounds.northWest);
            overallBounds.extend(routeBounds.southEast);
          }
        }
      }

      // Initialize vehicle positions to the start of their respective routes
      for (var vehicle in _vehiclesOnMap) {
        final assignedRouteInfo = _routeAnimationInfo[vehicle.routeId];
        if (assignedRouteInfo != null && assignedRouteInfo.polylinePoints.isNotEmpty) {
          vehicle.position = assignedRouteInfo.polylinePoints.first;
        } else {
          // If route not found or has no points, place vehicle at default center
          vehicle.position = _defaultNairobiCenter;
          debugPrint('Warning: Vehicle ${vehicle.id} has no assigned valid route or route has insufficient points. Placing at default.');
        }
      }

      // Fit map to overall bounds of all routes/vehicles
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && overallBounds != null) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: overallBounds!,
              padding: const EdgeInsets.all(50.0),
            ),
          );
        } else if (mounted) {
          // If no routes, fit to default Nairobi center
          _mapController.move(_defaultNairobiCenter, 12.0);
        }
      });

      // Start animation if we have vehicles and routes
      if (_vehiclesOnMap.isNotEmpty && _allRoutesOnMap.isNotEmpty) {
        _animationController.repeat(reverse: false);
      }

    } catch (e) {
      _errorMessage = 'Error loading map data: $e';
      if (mounted) {
        _showSnackBar(_errorMessage, isError: true);
      }
      debugPrint('Error loading sacco map data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  // This function updates each vehicle's position along its assigned route
  void _updateVehiclePositions() {
    if (_vehiclesOnMap.isEmpty || _allRoutesOnMap.isEmpty || _animationController.value == 0) return;

    // Use the single global animation controller's value
    final double animationProgress = _animationController.value; // 0.0 to 1.0

    for (var vehicle in _vehiclesOnMap) {
      final routeInfo = _routeAnimationInfo[vehicle.routeId];

      if (routeInfo != null && routeInfo.polylinePoints.length > 1) {
        final double animatedDistance = animationProgress * routeInfo.totalRouteLength;

        double accumulatedDistance = 0.0;
        math_latlong.LatLng? newVehiclePosition; // Use LatLng from flutter_map

        for (int i = 0; i < routeInfo.polylinePoints.length - 1; i++) {
          final segmentStart = routeInfo.polylinePoints[i];
          final segmentEnd = routeInfo.polylinePoints[i + 1];
          final segmentLength = routeInfo.segmentLengths[i];

          if (animatedDistance >= accumulatedDistance && animatedDistance <= accumulatedDistance + segmentLength) {
            final double segmentProgress = (animatedDistance - accumulatedDistance) / segmentLength;
            newVehiclePosition = math_latlong.LatLng( // Use LatLng from flutter_map
              segmentStart.latitude + (segmentEnd.latitude - segmentStart.latitude) * segmentProgress,
              segmentStart.longitude + (segmentEnd.longitude - segmentStart.longitude) * segmentProgress,
            );
            break; // Found segment, break loop
          }
          accumulatedDistance += segmentLength;
        }

        // Handle the case where animationProgress is 1.0 (at the end of the route)
        if (newVehiclePosition == null && animationProgress == 1.0) {
          newVehiclePosition = routeInfo.polylinePoints.last;
        }

        if (newVehiclePosition != null) {
          vehicle.position = newVehiclePosition;
        }
      } else {
        // If no valid route, keep vehicle at its initial or default position
        debugPrint('Vehicle ${vehicle.id} has no valid route (${vehicle.routeId}) or route has insufficient points for animation.');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
        // The error indicates _routePolylinePoints is "undefined" here.
        // This is highly unusual for a class member.
        // Let's ensure a robust fallback and confirm variable exists.
        initialCenter: _allRoutesOnMap.isNotEmpty && _routeAnimationInfo[_allRoutesOnMap.first.id]?.polylinePoints.isNotEmpty == true
            ? _routeAnimationInfo[_allRoutesOnMap.first.id]!.polylinePoints.first
            : _defaultNairobiCenter,
        initialZoom: 12.0, // Always provide a concrete initial zoom
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
        // Draw all routes
        ..._allRoutesOnMap.map((route) {
          final routeInfo = _routeAnimationInfo[route.id];
          if (routeInfo != null && routeInfo.polylinePoints.isNotEmpty) {
            return PolylineLayer(
              polylines: [
                Polyline(
                  points: routeInfo.polylinePoints,
                  color: Colors.teal.withAlpha((255 * 0.5).round()), // Lighter color for all routes
                  strokeWidth: 3.0,
                  borderColor: Colors.teal.withAlpha((255 * 0.3).round()),
                  borderStrokeWidth: 1.0,
                ),
              ],
            );
          }
          return const SizedBox.shrink(); // Return empty widget if no polyline
        }),
        // Draw markers for stages (waypoints) for all routes
        MarkerLayer(
          markers: [
            ..._allRoutesOnMap.expand((route) {
              return route.stages.map((stage) {
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
              });
            }), // Removed .toList() as expand already returns Iterable and spread handles it.
            // Markers for vehicles
            ..._vehiclesOnMap.map((vehicle) {
              return Marker(
                point: vehicle.position,
                width: 40.0,
                height: 40.0,
                rotate: true,
                child: Icon(
                  vehicle.icon,
                  color: vehicle.color,
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
    _mapController.dispose();
    super.dispose();
  }
}
