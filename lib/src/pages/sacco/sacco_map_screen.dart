import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'dart:convert'; // For JSON decoding

import 'package:flutter_map/flutter_map.dart'; // Provides MapController, TileLayer, Marker, Polyline, LatLng, LatLngBounds, MapOptions, CameraFit, InteractionOptions, InteractiveFlag
import 'package:latlong2/latlong.dart' as math_latlong; // Alias for Distance calculation and other latlong2 types to avoid conflict with flutter_map's LatLng
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import your models
import 'package:ma3_app/src/models/vehicle.dart'; // Ensure this path is correct
import 'package:ma3_app/src/models/route_data.dart';
import 'package:ma3_app/src/models/driver.dart';

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

// Real-time vehicle data from WebSocket
class VehicleLocationUpdate {
  final int driverId;
  final int vehicleId; // ADDED: To match backend broadcast
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double bearing;
  final double altitude;
  final DateTime timestamp;
  final String eventType;
  final bool isMoving;

  VehicleLocationUpdate({
    required this.driverId,
    required this.vehicleId, // ADDED
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.bearing,
    required this.altitude,
    required this.timestamp,
    required this.eventType,
    required this.isMoving,
  });

  factory VehicleLocationUpdate.fromJson(Map<String, dynamic> json) {
    return VehicleLocationUpdate(
      driverId: json['driver_id'] ?? 0,
      vehicleId: json['vehicle_id'] ?? 0, // ADDED
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      accuracy: (json['accuracy'] ?? 0.0).toDouble(),
      speed: (json['speed'] ?? 0.0).toDouble(),
      bearing: (json['bearing'] ?? 0.0).toDouble(),
      altitude: (json['altitude'] ?? 0.0).toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      eventType: json['event_type'] ?? 'unknown',
      isMoving: json['is_moving'] ?? false,
    );
  }

  math_latlong.LatLng get position => math_latlong.LatLng(latitude, longitude);
}

// Enhanced vehicle data with real-time tracking
class TrackedVehicle {
  final Vehicle vehicle; // Reference to the original Vehicle object
  math_latlong.LatLng position; // Current animated position
  double speed;
  double bearing;
  bool isMoving;
  DateTime lastUpdate;
  VehicleLocationUpdate? lastLocationData;
  
  // Animation properties for smooth movement
  math_latlong.LatLng? targetPosition;
  Timer? animationTimer; // This timer might be redundant with _animationUpdateTimer
  int animationSteps = 0;
  int totalAnimationSteps = 30; // 30 steps for smooth animation

  TrackedVehicle({
    required this.vehicle,
    required this.position,
    this.speed = 0.0,
    this.bearing = 0.0,
    this.isMoving = false,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  void updateFromLocationData(VehicleLocationUpdate locationData) {
    lastLocationData = locationData;
    // Set new target position from incoming data
    targetPosition = locationData.position;
    speed = locationData.speed;
    bearing = locationData.bearing;
    isMoving = locationData.isMoving;
    lastUpdate = locationData.timestamp;
    animationSteps = 0; // Reset animation for new target
  }

  // Update animation step - called by a central timer
  void updateAnimation() {
    if (targetPosition != null && animationSteps < totalAnimationSteps) {
      animationSteps++;
      if (animationSteps >= totalAnimationSteps) {
        position = targetPosition!; // Final position snapped
        targetPosition = null;      // Clear target
      } else {
        // Interpolate position during animation
        final progress = animationSteps / totalAnimationSteps;
        final latDiff = targetPosition!.latitude - position.latitude;
        final lngDiff = targetPosition!.longitude - position.longitude;
        
        position = math_latlong.LatLng(
          position.latitude + (latDiff * progress),
          position.longitude + (lngDiff * progress),
        );
      }
    }
  }
}


class SaccoMapScreen extends StatefulWidget {
  const SaccoMapScreen({super.key});

  @override
  State<SaccoMapScreen> createState() => _SaccoMapScreenState();
}

class _SaccoMapScreenState extends State<SaccoMapScreen> with SingleTickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _animationController; // Used for general animations, not directly for vehicle movement anymore.

  List<Vehicle> _vehiclesOnMap = []; // All fetched vehicles (their position will be updated)
  List<RouteData> _allRoutesOnMap = []; // All fetched routes
  Map<int, RouteData> _routeIdToRouteData = {}; // Map to quickly find RouteData by ID
  Map<int, _RouteCalculatedInfo> _routeAnimationInfo = {}; // Pre-calculated animation data per route
  
  // WebSocket and real-time tracking
  WebSocketChannel? _locationChannel;
  Map<int, TrackedVehicle> _trackedVehicles = {}; // Map driver ID to tracked vehicle
  Map<int, int> _vehicleToDriverMap = {}; // Map vehicle ID to driver ID (useful for reverse lookup)
  Timer? _animationUpdateTimer; // Central timer for all vehicle animations
  bool _isWebSocketConnected = false;

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
      duration: const Duration(milliseconds: 100),
    );

    // Start animation timer for smooth vehicle movement (updates all tracked vehicles)
    _animationUpdateTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (mounted) {
        setState(() {
          _updateVehicleAnimations();
        });
      }
    });

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
      _trackedVehicles = {}; // Clear previous tracked vehicles on reload
      _vehicleToDriverMap = {}; // Clear previous mappings
    });

    try {
      final int? saccoId = await TokenStorage.getSaccoId();
      if (saccoId == null) {
        throw Exception('Sacco ID not found. Cannot fetch data.');
      }

      // 1. Fetch all Vehicles for the authenticated Sacco
      final List<Vehicle> fetchedVehicles = await SaccoService.fetchVehiclesBySacco();
      _vehiclesOnMap = fetchedVehicles; // Assign directly

      // 2. Fetch all Routes for the authenticated Sacco
      final List<RouteData> fetchedRoutes = await SaccoService.fetchRoutesBySacco();
      _allRoutesOnMap = fetchedRoutes;

      // Prepare lookup map and pre-calculate animation info for each route
      LatLngBounds? overallBounds;

      for (var route in _allRoutesOnMap) {
        _routeIdToRouteData[route.id] = route;

        List<math_latlong.LatLng> polylinePoints = [];
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
          final routeBounds = LatLngBounds.fromPoints(polylinePoints);
          if (overallBounds == null) {
            overallBounds = routeBounds;
          } else {
            overallBounds.extend(routeBounds.northWest);
            overallBounds.extend(routeBounds.southEast);
          }
        }
      }

      // Initialize tracked vehicles from fetched vehicle data and assign initial positions
      await _initializeTrackedVehicles();
      
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

      // Connect to WebSocket after all initial data is loaded
      await _connectToLocationWebSocket();
      
      debugPrint('Loaded ${_vehiclesOnMap.length} vehicles and ${_allRoutesOnMap.length} routes');
      debugPrint('Initialized ${_trackedVehicles.length} tracked vehicles');

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


  /// Initialize tracked vehicles from loaded vehicle data
  /// This sets up the initial positions for vehicles and the driver-to-vehicle mapping.
  Future<void> _initializeTrackedVehicles() async {
    _trackedVehicles.clear();
    _vehicleToDriverMap.clear();
    
    try {
      // Fetch drivers for all vehicles to map vehicle ID to driver ID
      final drivers = await SaccoService.fetchDriversBySacco();
      
      for (var vehicle in _vehiclesOnMap) {
        // Find the driver assigned to this vehicle
        final driver = drivers.firstWhere(
          (d) => d.vehicleId == vehicle.id,
          orElse: () => Driver( // Provide a dummy Driver if not found to avoid errors
            id: 0,
            name: 'Unknown',
            email: 'unknown@example.com',
            phone: '',
            licenseNumber: '',
            saccoId: 0,
            vehicleId: vehicle.id,
          ),
        );
        
        if (driver.id > 0) { // Only track if a valid driver is found
          _vehicleToDriverMap[vehicle.id] = driver.id; // Map vehicle ID to driver ID
          
          // Determine initial position for the vehicle (start of its route or default)
          final routeInfo = _routeAnimationInfo[vehicle.routeId];
          final initialPosition = routeInfo?.polylinePoints.isNotEmpty == true
              ? routeInfo!.polylinePoints.first
              : _defaultNairobiCenter;
          
          // Set the initial position directly on the Vehicle object itself
          vehicle.position = initialPosition;
              
          // Create and store the TrackedVehicle, keyed by driver.id
          _trackedVehicles[driver.id] = TrackedVehicle(
            vehicle: vehicle, // Pass the vehicle object by reference
            position: initialPosition,
          );
          
          debugPrint('Initialized tracked vehicle: ${vehicle.vehicleRegistration} (Vehicle ID: ${vehicle.id}) -> Driver ID: ${driver.id}');
        } else {
            debugPrint('Warning: No driver found for vehicle ${vehicle.vehicleRegistration} (ID: ${vehicle.id}). It will not be tracked.');
        }
      }
    } catch (e) {
      debugPrint('Error initializing tracked vehicles: $e');
      _showSnackBar('Error initializing vehicle tracking.', isError: true);
    }
  }
  
  /// Connect to WebSocket for real-time location updates
  Future<void> _connectToLocationWebSocket() async {
    try {
      final wsUrl = dotenv.env['BACKEND_WS_URL'];
      if (wsUrl == null) {
        debugPrint('WebSocket URL not found in environment');
        _showSnackBar('WebSocket URL not configured.', isError: true);
        return;
      }
      
      final token = await TokenStorage.getToken();
      if (token == null) {
        debugPrint('Authentication token not found');
        _showSnackBar('Authentication token missing for WebSocket.', isError: true);
        return;
      }

      final saccoId = await TokenStorage.getSaccoId();
      if (saccoId == null) {
        debugPrint('Sacco ID not found for WebSocket connection.');
        _showSnackBar('Sacco ID missing for WebSocket connection.', isError: true);
        return;
      }
      
      // Construct WebSocket URI with token and sacco_id query parameters
      final wsUri = Uri.parse('$wsUrl?token=$token&sacco_id=$saccoId');
      _locationChannel = WebSocketChannel.connect(wsUri);
      
      _locationChannel!.stream.listen(
        (message) {
          _handleLocationUpdate(message);
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _isWebSocketConnected = false;
          // Attempt to reconnect after a delay
          Timer(const Duration(seconds: 5), () {
            if (mounted) {
              debugPrint('Attempting to reconnect WebSocket...');
              _connectToLocationWebSocket();
            }
          });
          _showSnackBar('WebSocket disconnected. Attempting reconnect...', isError: true);
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isWebSocketConnected = false;
          _showSnackBar('WebSocket error: $error', isError: true);
        },
      );
      
      _isWebSocketConnected = true;
      debugPrint('Connected to location WebSocket: $wsUri');
      _showSnackBar('Connected to live tracking.', isError: false);
      
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      _isWebSocketConnected = false;
      _showSnackBar('Failed to connect to live tracking: $e', isError: true);
    }
  }
  
  /// Handle incoming location updates from WebSocket
  void _handleLocationUpdate(dynamic message) {
    try {
      final Map<String, dynamic> data = json.decode(message);
      final locationUpdate = VehicleLocationUpdate.fromJson(data);
      
      final trackedVehicle = _trackedVehicles[locationUpdate.driverId];
      if (trackedVehicle != null) {
        trackedVehicle.updateFromLocationData(locationUpdate);
        debugPrint('Updated vehicle position for driver ${locationUpdate.driverId}: ${locationUpdate.position}');
        
        // Trigger UI update
        // setState is called by the central _animationUpdateTimer,
        // so direct setState here might not be strictly necessary for animation,
        // but it ensures immediate reaction for non-animated updates or data changes.
        // if (mounted) {
        //   setState(() {});
        // }
      } else {
        debugPrint('Received location update for unknown driver: ${locationUpdate.driverId}. Vehicle ID: ${locationUpdate.vehicleId}');
        // Optionally, fetch vehicle/driver info for unknown drivers and add to _trackedVehicles
      }
    } catch (e) {
      debugPrint('Error handling location update: $e');
      _showSnackBar('Error processing live update: $e', isError: true);
    }
  }
  
  /// Update vehicle animations for smooth movement
  /// This method is called periodically by [_animationUpdateTimer]
  void _updateVehicleAnimations() {
    bool needsSetState = false;
    
    for (var trackedVehicle in _trackedVehicles.values) {
      if (trackedVehicle.targetPosition != null) {
        trackedVehicle.updateAnimation();
        // After updating the trackedVehicle's animated position, update the
        // position of the corresponding Vehicle object in _vehiclesOnMap.
        // This is crucial because the MarkerLayer uses `_vehiclesOnMap` directly.
        if (trackedVehicle.vehicle.position != trackedVehicle.position) {
          trackedVehicle.vehicle.position = trackedVehicle.position;
          needsSetState = true;
        }
      }
    }
    
    // Only call setState if any vehicle's position actually changed during animation
    if (needsSetState && mounted) {
      setState(() {
        // UI rebuild triggered here for vehicle marker positions
      });
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
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 10),
              Text(
                'Error: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadSaccoMapData, // Retry loading
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Vehicle Tracking'),
        backgroundColor: Colors.teal,
        actions: [
          // WebSocket status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _isWebSocketConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isWebSocketConnected ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                // Display count of tracked vehicles that have received at least one update
                Text(
                  '${_trackedVehicles.values.where((v) => v.lastLocationData != null).length}/${_trackedVehicles.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          // Safely determine initialCenter, ensuring polylinePoints exists
          initialCenter: (_allRoutesOnMap.isNotEmpty && _routeAnimationInfo[_allRoutesOnMap.first.id]?.polylinePoints.isNotEmpty == true)
              ? _routeAnimationInfo[_allRoutesOnMap.first.id]!.polylinePoints.first
              : _defaultNairobiCenter,
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
                      const Icon(
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
            }),
            // Markers for vehicles with real-time status
            ..._vehiclesOnMap.map((vehicle) {
              // Now `vehicle.position` should be correctly updated by `_updateVehicleAnimations`
              final driverId = _vehicleToDriverMap[vehicle.id]; // Get driver ID for this vehicle
              final trackedVehicle = driverId != null ? _trackedVehicles[driverId] : null; // Get tracked vehicle data
              final isRealTime = trackedVehicle?.lastLocationData != null;
              final isMoving = trackedVehicle?.isMoving ?? false;
              
              return Marker(
                point: vehicle.position, // Use the position directly from the Vehicle object
                width: 50.0,
                height: 60.0,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Vehicle icon with rotation based on bearing
                        Transform.rotate(
                          angle: (trackedVehicle?.bearing ?? 0) * 3.14159 / 180, // Radians for Transform.rotate
                          child: Icon(
                            vehicle.icon,
                            color: isRealTime 
                              ? (isMoving ? Colors.green : Colors.orange) // Green for moving, Orange for stopped but real-time
                              : Colors.grey, // Grey for not real-time
                            size: 30.0,
                          ),
                        ),
                        // Real-time indicator
                        if (isRealTime)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isMoving ? Colors.green : Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Vehicle registration
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        vehicle.vehicleRegistration,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _animationUpdateTimer?.cancel();
    _locationChannel?.sink.close();
    _mapController.dispose();
    
    // Clean up tracked vehicle timers (if any were created per-vehicle, though current design uses central timer)
    for (var trackedVehicle in _trackedVehicles.values) {
      trackedVehicle.animationTimer?.cancel(); // Just in case, though it should be null
    }
    
    super.dispose();
  }
}
