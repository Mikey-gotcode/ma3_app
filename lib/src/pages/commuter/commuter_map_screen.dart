// lib/src/screens/commuter_map_screen.dart
import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'dart:convert'; // For JSON decoding

import 'package:flutter_map/flutter_map.dart'; // Provides MapController, TileLayer, Marker, Polyline, LatLng, LatLngBounds, MapOptions, CameraFit, InteractionOptions, InteractiveFlag
import 'package:latlong2/latlong.dart'
    as math_latlong; // Alias for Distance calculation and other latlong2 types to avoid conflict with flutter_map's LatLng
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart'; // For getting current location

// Import your models
import 'package:ma3_app/src/models/vehicle.dart'; // Ensure this path is correct
import 'package:ma3_app/src/models/route_data.dart';
import 'package:ma3_app/src/models/driver.dart';

// Import the Commuter service (UPDATED)
import 'package:ma3_app/src/services/commuter_service.dart'; // Use the new commuter service
import 'package:ma3_app/src/services/token_storage.dart'; // To get token (saccoId is no longer directly used for fetches)

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
  final int vehicleId;
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
    required this.vehicleId,
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
      driverId: (json['driver_id'] as num?)?.toInt() ?? 0,
      vehicleId: (json['vehicle_id'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      bearing: (json['bearing'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      eventType: json['event_type'] ?? 'unknown',
      isMoving: json['is_moving'] ?? false,
    );
  }

  math_latlong.LatLng get position => math_latlong.LatLng(latitude, longitude);
}

// Enhanced vehicle data with real-time tracking
class TrackedVehicle {
  final Vehicle vehicle;
  math_latlong.LatLng position;
  double speed;
  double bearing;
  bool isMoving;
  DateTime lastUpdate;
  VehicleLocationUpdate? lastLocationData;

  // Animation properties for smooth movement
  math_latlong.LatLng? targetPosition;
  Timer? animationTimer;
  int animationSteps = 0;
  int totalAnimationSteps = 30;

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
    targetPosition = locationData.position;
    speed = locationData.speed;
    bearing = locationData.bearing;
    isMoving = locationData.isMoving;
    lastUpdate = locationData.timestamp;
    animationSteps = 0;
  }

  void updateAnimation() {
    if (targetPosition != null && animationSteps < totalAnimationSteps) {
      animationSteps++;
      if (animationSteps >= totalAnimationSteps) {
        position = targetPosition!;
        targetPosition = null;
      } else {
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

class CommuterMapScreen extends StatefulWidget {
  const CommuterMapScreen({super.key});

  @override
  State<CommuterMapScreen> createState() => _CommuterMapScreenState();
}

class _CommuterMapScreenState extends State<CommuterMapScreen>
    with SingleTickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _animationController;

  List<Vehicle> _vehiclesOnMap = [];
  List<RouteData> _allRoutesOnMap = [];
  Map<int, RouteData> _routeIdToRouteData = {};
  Map<int, _RouteCalculatedInfo> _routeAnimationInfo = {};

  WebSocketChannel? _locationChannel;
  Map<int, TrackedVehicle> _trackedVehicles = {};
  Map<int, int> _vehicleToDriverMap = {};
  Timer? _animationUpdateTimer;
  bool _isWebSocketConnected = false;

  bool _isLoading = true;
  String _errorMessage = '';

  // Search bar related state
  final TextEditingController _startLocationController =
      TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _startLocationSuggestions = [];
  List<Map<String, dynamic>> _endLocationSuggestions = [];
  bool _isSearchingStartLocation = false;
  bool _isSearchingEndLocation = false;

  math_latlong.LatLng? _selectedStartLatLng;
  math_latlong.LatLng? _selectedEndLatLng;
  List<List<math_latlong.LatLng>> _foundRoutePolylines =
      []; // For multi-leg routes

  static const math_latlong.LatLng _defaultNairobiCenter = math_latlong.LatLng(
    -1.286389,
    36.817223,
  );

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _animationUpdateTimer = Timer.periodic(const Duration(milliseconds: 33), (
      timer,
    ) {
      if (mounted) {
        setState(() {
          _updateVehicleAnimations();
        });
      }
    });

    _startLocationController.addListener(
      () => _onSearchChanged(_startLocationController.text, true),
    );
    _endLocationController.addListener(
      () => _onSearchChanged(_endLocationController.text, false),
    );

    _loadCommuterMapData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _animationUpdateTimer?.cancel();
    _locationChannel?.sink.close();
    _mapController.dispose();
    _debounce?.cancel();
    _startLocationController.dispose();
    _endLocationController.dispose();

    for (var trackedVehicle in _trackedVehicles.values) {
      trackedVehicle.animationTimer?.cancel();
    }

    super.dispose();
  }

  Future<void> _loadCommuterMapData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _vehiclesOnMap = [];
      _allRoutesOnMap = [];
      _routeIdToRouteData = {};
      _routeAnimationInfo = {};
      _trackedVehicles = {};
      _vehicleToDriverMap = {};
    });

    try {
      // Fetch all vehicles (no saccoId filter)
      await _fetchAllVehicles();

      // Fetch all routes (no saccoId filter)
      final List<RouteData> fetchedRoutes =
          await CommuterService.fetchAllRoutes(); // Using CommuterService
      _allRoutesOnMap = fetchedRoutes;

      // Prepare lookup map and pre-calculate animation info for each route
      LatLngBounds? overallBounds;

      for (var route in _allRoutesOnMap) {
        _routeIdToRouteData[route.id] = route;

        List<math_latlong.LatLng> polylinePoints = [];
        if (route.geometry.isNotEmpty) {
          try {
            final Map<String, dynamic> geoJson = json.decode(route.geometry);
            if (geoJson['type'] == 'LineString' &&
                geoJson['coordinates'] is List) {
              polylinePoints = (geoJson['coordinates'] as List)
                  .map(
                    (coord) => math_latlong.LatLng(
                      coord[1] as double,
                      coord[0] as double,
                    ),
                  )
                  .toList();
            } else {
              debugPrint(
                'Warning: Route ID ${route.id} geometry is not a valid LineString GeoJSON. Falling back to stages.',
              );
              polylinePoints = route.stages.map((s) => s.toLatLng()).toList();
            }
          } catch (e) {
            debugPrint(
              'Error parsing geometry for route ID ${route.id} as GeoJSON: $e. Falling back to stages.',
            );
            polylinePoints = route.stages.map((s) => s.toLatLng()).toList();
          }
        } else {
          polylinePoints = route.stages.map((s) => s.toLatLng()).toList();
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

      await _initializeTrackedVehicles();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && overallBounds != null) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: overallBounds!,
              padding: const EdgeInsets.all(50.0),
            ),
          );
        } else if (mounted) {
          _mapController.move(_defaultNairobiCenter, 12.0);
        }
      });

      // Connect to WebSocket after all initial data is loaded to get active locations
      await _connectToLocationWebSocket();

      debugPrint(
        'Loaded ${_vehiclesOnMap.length} vehicles and ${_allRoutesOnMap.length} routes',
      );
      debugPrint('Initialized ${_trackedVehicles.length} tracked vehicles');
    } catch (e) {
      _errorMessage = 'Error loading map data: $e';
      if (mounted) {
        _showSnackBar(_errorMessage, isError: true);
      }
      debugPrint('Error loading commuter map data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // New method: Fetches all vehicles (no saccoId filter)
  Future<void> _fetchAllVehicles() async {
    try {
      final List<Vehicle> fetchedVehicles =
          await CommuterService.fetchAllVehicles(); // Using CommuterService
      _vehiclesOnMap = fetchedVehicles;
      debugPrint('Fetched ${_vehiclesOnMap.length} vehicles.');
      debugPrint(
        'IDs of fetched vehicles: ${_vehiclesOnMap.map((v) => v.id).join(', ')}',
      );
    } catch (e) {
      debugPrint('Error fetching all vehicles: $e');
      _showSnackBar('Error fetching all vehicles: $e', isError: true);
      rethrow;
    }
  }

  /// Initialize tracked vehicles from loaded vehicle data
  /// This sets up the initial positions for vehicles and the driver-to-vehicle mapping.
  Future<void> _initializeTrackedVehicles() async {
    _trackedVehicles.clear();
    _vehicleToDriverMap.clear();

    try {
      // Fetch all drivers (no saccoId filter)
      final drivers =
          await CommuterService.fetchAllDrivers(); // Using CommuterService

      for (var vehicle in _vehiclesOnMap) {
        final driver = drivers.firstWhere(
          (d) => d.vehicleId == vehicle.id,
          orElse: () => Driver(
            id: 0,
            name: 'Unknown',
            email: 'unknown@example.com',
            phone: '',
            licenseNumber: '',
            saccoId: 0, // SaccoId might not be relevant for commuter view here
            vehicleId: vehicle.id,
          ),
        );

        if (driver.id > 0) {
          _vehicleToDriverMap[vehicle.id] = driver.id;

          final routeInfo = _routeAnimationInfo[vehicle.routeId];
          final initialPosition = routeInfo?.polylinePoints.isNotEmpty == true
              ? routeInfo!.polylinePoints.first
              : _defaultNairobiCenter;

          vehicle.position = initialPosition;

          _trackedVehicles[driver.id] = TrackedVehicle(
            vehicle: vehicle,
            position: initialPosition,
          );

          debugPrint(
            'Initialized tracked vehicle: ${vehicle.vehicleRegistration} (Vehicle ID: ${vehicle.id}) -> Driver ID: ${driver.id}',
          );
        } else {
          debugPrint(
            'Warning: No driver found for vehicle ${vehicle.vehicleRegistration} (ID: ${vehicle.id}). It will not be tracked.',
          );
        }
      }
      debugPrint(
        'Tracked Vehicles after initialization: ${_trackedVehicles.keys.map((k) => 'Driver $k').join(', ')}',
      );
    } catch (e) {
      debugPrint('Error initializing tracked vehicles: $e');
      _showSnackBar('Error initializing vehicle tracking.', isError: true);
    }
  }

  /// Connect to WebSocket for real-time location updates
  /// This method effectively "fetches all active vehicle locations" as they stream in.
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
        _showSnackBar(
          'Authentication token missing for WebSocket.',
          isError: true,
        );
        return;
      }

      // For WebSocket, saccoId is still needed if your backend filters by it for broadcasting.
      // If your backend broadcasts ALL public vehicle locations regardless of saccoId,
      // then this parameter might become optional in the future.
      final saccoId = await TokenStorage.getSaccoId();
      if (saccoId == null) {
        debugPrint(
          'Sacco ID not found for WebSocket connection. Attempting connection without it.',
        );
        // Optionally, you might decide to throw an error or connect without sacco_id
        // if your backend supports a general commuter websocket.
        // For now, we'll proceed with saccoId=0 or handle the error.
        // If saccoId is truly not needed for commuter websocket, remove this check.
      }

      // Construct WebSocket URI with token and sacco_id query parameters
      // Assuming backend still needs sacco_id for WebSocket filtering.
      final wsUri = Uri.parse('$wsUrl?token=$token&sacco_id=${saccoId ?? 0}');
      _locationChannel = WebSocketChannel.connect(wsUri);

      _locationChannel!.stream.listen(
        (message) {
          _handleLocationUpdate(message);
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _isWebSocketConnected = false;
          Timer(const Duration(seconds: 5), () {
            if (mounted) {
              debugPrint('Attempting to reconnect WebSocket...');
              _connectToLocationWebSocket();
            }
          });
          _showSnackBar(
            'WebSocket disconnected. Attempting reconnect...',
            isError: true,
          );
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

      TrackedVehicle? trackedVehicle =
          _trackedVehicles[locationUpdate.driverId];

      if (trackedVehicle == null) {
        // If trackedVehicle is null, try to find the Vehicle object using vehicleId
        Vehicle? vehicleInList;
        try {
          vehicleInList = _vehiclesOnMap.firstWhere(
            (v) => v.id == locationUpdate.vehicleId,
          );
        } catch (e) {
          debugPrint(
            'Vehicle ID ${locationUpdate.vehicleId} not found in _vehiclesOnMap. Creating placeholder.',
          );
        }

        if (vehicleInList == null) {
          // If vehicle not found in _vehiclesOnMap, create a placeholder Vehicle object
          vehicleInList = Vehicle(
            id: locationUpdate.vehicleId,
            vehicleNo: 'Unknown ${locationUpdate.vehicleId}',
            vehicleRegistration: 'N/A',
            saccoId: -1,
            driverId: locationUpdate.driverId,
            inService: true,
            routeId: 0,
            position: locationUpdate.position,
          );
          _vehiclesOnMap.add(vehicleInList);
          debugPrint(
            'Added placeholder vehicle ${vehicleInList.id} to _vehiclesOnMap.',
          );
        }

        trackedVehicle = TrackedVehicle(
          vehicle: vehicleInList,
          position: locationUpdate.position,
          speed: locationUpdate.speed,
          bearing: locationUpdate.bearing,
          isMoving: locationUpdate.isMoving,
          lastUpdate: locationUpdate.timestamp,
        );
        _trackedVehicles[locationUpdate.driverId] = trackedVehicle;
        _vehicleToDriverMap[vehicleInList.id] = locationUpdate.driverId;
        debugPrint(
          'Dynamically added tracked vehicle for driver ${locationUpdate.driverId} (Vehicle ID: ${locationUpdate.vehicleId}) from live update.',
        );
      }

      trackedVehicle!.updateFromLocationData(locationUpdate);
      debugPrint(
        'Updated vehicle position for driver ${locationUpdate.driverId} (Vehicle ID: ${locationUpdate.vehicleId}): ${locationUpdate.position}',
      );
    } catch (e) {
      debugPrint('Error handling location update: $e');
      _showSnackBar('Error processing live update: $e', isError: true);
    }
  }

  /// Update vehicle animations for smooth movement
  void _updateVehicleAnimations() {
    bool needsSetState = false;

    for (var trackedVehicle in _trackedVehicles.values) {
      if (trackedVehicle.targetPosition != null) {
        trackedVehicle.updateAnimation();
        if (trackedVehicle.vehicle.position != trackedVehicle.position) {
          trackedVehicle.vehicle.position = trackedVehicle.position;
          needsSetState = true;
        }
      }
    }

    if (needsSetState && mounted) {
      setState(() {});
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

  // --- Search Bar Methods ---

  void _onSearchChanged(String text, bool isStartLocation) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(text, isStartLocation);
    });
  }

  Future<void> _performSearch(String query, bool isStartLocation) async {
    if (!mounted) return;
    setState(() {
      if (isStartLocation) {
        _isSearchingStartLocation = true;
        _startLocationSuggestions = [];
      } else {
        _isSearchingEndLocation = true;
        _endLocationSuggestions = [];
      }
    });

    try {
      // Pass current location as 'near' for better relevance if available
      math_latlong.LatLng? currentLocation;
      if (isStartLocation && _selectedStartLatLng != null) {
        currentLocation = _selectedStartLatLng;
      } else if (!isStartLocation && _selectedEndLatLng != null) {
        currentLocation = _selectedEndLatLng;
      }

      final suggestions = await CommuterService.searchPlaces(
        query,
        near: currentLocation,
      );
      if (mounted) {
        setState(() {
          if (isStartLocation) {
            _startLocationSuggestions = suggestions;
          } else {
            _endLocationSuggestions = suggestions;
          }
        });
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
      if (mounted) {
        _showSnackBar('Error searching places: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isStartLocation) {
            _isSearchingStartLocation = false;
          } else {
            _isSearchingEndLocation = false;
          }
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isSearchingStartLocation = true;
      _startLocationController.text = 'Getting current location...';
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted)
            _showSnackBar('Location permissions are denied', isError: true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted)
          _showSnackBar(
            'Location permissions are permanently denied, we cannot request permissions.',
            isError: true,
          );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _selectedStartLatLng = math_latlong.LatLng(
            position.latitude,
            position.longitude,
          );
          _startLocationController.text =
              'My Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          _startLocationSuggestions = []; // Clear suggestions
          _isSearchingStartLocation = false;
          _mapController.move(
            _selectedStartLatLng!,
            14.0,
          ); // Move map to current location
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        _showSnackBar('Error getting current location: $e', isError: true);
        _startLocationController.text = ''; // Clear text on error
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingStartLocation = false;
        });
      }
    }
  }

  Future<void> _findAndDisplayRoute() async {
    if (_selectedStartLatLng == null || _selectedEndLatLng == null) {
      _showSnackBar(
        'Please select both start and end locations.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true; // Use main loading indicator for route search
      _foundRoutePolylines = []; // Clear previous routes
    });

    try {
      // This calls the backend to find the optimal route (1, 2, or 3 legs)
      final List<RouteData> routes = await CommuterService.findOptimalRoute(
        _selectedStartLatLng!,
        _selectedEndLatLng!,
      );

      if (mounted) {
        setState(() {
          _foundRoutePolylines = routes.map((route) {
            if (route.geometry.isNotEmpty) {
              try {
                final Map<String, dynamic> geoJson = json.decode(
                  route.geometry,
                );
                if (geoJson['type'] == 'LineString' &&
                    geoJson['coordinates'] is List) {
                  return (geoJson['coordinates'] as List)
                      .map(
                        (coord) => math_latlong.LatLng(
                          coord[1] as double,
                          coord[0] as double,
                        ),
                      )
                      .toList();
                }
              } catch (e) {
                debugPrint('Error parsing route geometry for display: $e');
              }
            }
            // Fallback if geometry is invalid or empty
            return route.stages.map((s) => s.toLatLng()).toList();
          }).toList();

          if (_foundRoutePolylines.isNotEmpty) {
            // Fit map to the found route(s)
            final allPoints = _foundRoutePolylines
                .expand((list) => list)
                .toList();
            if (allPoints.isNotEmpty) {
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(allPoints),
                  padding: const EdgeInsets.all(50.0),
                ),
              );
            }
            _showSnackBar('Route found!', isError: false);
          } else {
            _showSnackBar('No direct or multi-leg route found.', isError: true);
          }
        });
      }
    } catch (e) {
      debugPrint('Error finding route: $e');
      if (mounted) {
        _showSnackBar('Error finding route: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _foundRoutePolylines.isEmpty && _vehiclesOnMap.isEmpty) {
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
                onPressed: _loadCommuterMapData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                (_allRoutesOnMap.isNotEmpty &&
                    _routeAnimationInfo[_allRoutesOnMap.first.id]
                            ?.polylinePoints
                            .isNotEmpty ==
                        true)
                ? _routeAnimationInfo[_allRoutesOnMap.first.id]!
                      .polylinePoints
                      .first
                : _defaultNairobiCenter,
            initialZoom: 12.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.ma3_app',
              retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
            ),
            // Draw all static routes
            ..._allRoutesOnMap.map((route) {
              final routeInfo = _routeAnimationInfo[route.id];
              if (routeInfo != null && routeInfo.polylinePoints.isNotEmpty) {
                return PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routeInfo.polylinePoints,
                      color: Colors.teal.withAlpha((255 * 0.5).round()),
                      strokeWidth: 3.0,
                      borderColor: Colors.teal.withAlpha((255 * 0.3).round()),
                      borderStrokeWidth: 1.0,
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),
            // Draw found optimal route(s) (can be multi-leg)
            ..._foundRoutePolylines.map((polylinePoints) {
              if (polylinePoints.isNotEmpty) {
                return PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
                      color: Colors.blue.withOpacity(
                        0.7,
                      ), // Distinct color for found route
                      strokeWidth: 5.0,
                      borderColor: Colors.blue.withOpacity(0.5),
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
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
                  final driverId = _vehicleToDriverMap[vehicle.id];
                  final trackedVehicle = driverId != null
                      ? _trackedVehicles[driverId]
                      : null;
                  final isRealTime = trackedVehicle?.lastLocationData != null;
                  final isMoving = trackedVehicle?.isMoving ?? false;

                  return Marker(
                    point: vehicle.position,
                    width: 50.0,
                    height: 60.0,
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle:
                                  (trackedVehicle?.bearing ?? 0) *
                                  3.14159 /
                                  180,
                              child: Icon(
                                vehicle.icon,
                                color: isRealTime
                                    ? (isMoving ? Colors.green : Colors.orange)
                                    : Colors.grey,
                                size: 30.0,
                              ),
                            ),
                            if (isRealTime)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: isMoving
                                        ? Colors.green
                                        : Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
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
        // Search Bar Overlay
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: SafeArea(
            child: Column(
              children: [
                // Start Location Input
                _buildLocationInput(
                  controller: _startLocationController,
                  hintText: 'Start Location',
                  isStartLocation: true,
                  suggestions: _startLocationSuggestions,
                  isLoading: _isSearchingStartLocation,
                  onClear: () {
                    setState(() {
                      _startLocationController.clear();
                      _selectedStartLatLng = null;
                      _startLocationSuggestions = [];
                    });
                  },
                  onCurrentLocation: _getCurrentLocation,
                ),
                const SizedBox(height: 10),
                // End Location Input
                _buildLocationInput(
                  controller: _endLocationController,
                  hintText: 'End Location',
                  isStartLocation: false,
                  suggestions: _endLocationSuggestions,
                  isLoading: _isSearchingEndLocation,
                  onClear: () {
                    setState(() {
                      _endLocationController.clear();
                      _selectedEndLatLng = null;
                      _endLocationSuggestions = [];
                    });
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _findAndDisplayRoute,
                  icon: const Icon(Icons.alt_route),
                  label: const Text('Find Route'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(
                      double.infinity,
                      45,
                    ), // Full width button
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // WebSocket Status Indicator (moved to top-right corner)
        Positioned(
          top: 10,
          right: 10,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInput({
    required TextEditingController controller,
    required String hintText,
    required bool isStartLocation,
    required List<Map<String, dynamic>> suggestions,
    required bool isLoading,
    VoidCallback? onClear,
    VoidCallback? onCurrentLocation,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(
                isStartLocation ? Icons.location_on : Icons.flag,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (onClear != null && controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClear,
                    ),
                  if (isStartLocation && onCurrentLocation != null)
                    IconButton(
                      icon: const Icon(Icons.my_location),
                      onPressed: onCurrentLocation,
                      tooltip: 'Get Current Location',
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          if (suggestions.isNotEmpty && controller.text.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200,
              ), // Limit height of suggestions
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    title: Text(suggestion['name'] as String),
                    subtitle: Text(
                      'Lat: ${suggestion['latitude']?.toStringAsFixed(4)}, Lng: ${suggestion['longitude']?.toStringAsFixed(4)}',
                    ),
                    onTap: () {
                      setState(() {
                        controller.text = suggestion['name'] as String;
                        final latLng = math_latlong.LatLng(
                          suggestion['latitude'] as double,
                          suggestion['longitude'] as double,
                        );
                        if (isStartLocation) {
                          _selectedStartLatLng = latLng;
                          _startLocationSuggestions = []; // Clear suggestions
                        } else {
                          _selectedEndLatLng = latLng;
                          _endLocationSuggestions = []; // Clear suggestions
                        }
                        _mapController.move(
                          latLng,
                          14.0,
                        ); // Move map to selected location
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
