import 'dart:async'; // For Timer and StreamSubscription
import 'dart:convert'; // For jsonEncode

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For WebSocket URL
import 'package:ma3_app/src/models/vehicle.dart';
import 'package:ma3_app/src/services/driver_service.dart';
import 'package:ma3_app/src/services/token_storage.dart';

// Map-related imports
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ma3_app/src/services/geoclue_location_service.dart'; // For location
import 'package:ma3_app/src/services/intelligent_location_service.dart'; // For intelligent location
import 'package:web_socket_channel/web_socket_channel.dart'; // For WebSockets

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Vehicle? _driverVehicle;
  bool _isLoading = true;
  bool _isInService = false; // Initial state for the toggle
  bool _isDetailsExpanded = true; // State for the collapsible card

  final DriverService _driverService = DriverService();

  // Location-related variables
  LatLng? _currentLatLng; // Stores current device location
  Timer? _locationUpdateTimer; // Timer for dynamic location updates
  bool _isLocationServiceEnabled = false;
  bool _hasLocationPermission = false;
  LocationPoint? _lastLocationPoint; // Last intelligent location point
  String _movementStatus = 'Unknown'; // Current movement status

  // WebSocket-related variables
  WebSocketChannel? _locationWsChannel;
  String? _webSocketUrl; // Store WebSocket URL from .env
  bool _isWebSocketConnected = false;
  bool _isLocationInitialized = false; // New state variable

  @override
  void initState() {
    super.initState();
    debugPrint('MapScreen initState: Starting initialization.');
    _fetchDriverVehicle();
    _initializeLocationAndWebSocket().then((_) {
      if (mounted) {
        setState(() {
          _isLocationInitialized = true;
        });
        debugPrint('MapScreen initState: Location initialization complete. _isLocationInitialized set to true.');
        if (_isInService) {
          debugPrint('MapScreen initState: _isInService is true, attempting to start transmission.');
          _startLocationAndWebSocketTransmission();
        }
      }
    });
  }

  @override
  void dispose() {
    debugPrint('MapScreen dispose: Cancelling timer and closing WebSocket.');
    _locationUpdateTimer?.cancel(); // Cancel location timer
    _locationWsChannel?.sink.close(); // Close WebSocket connection
    super.dispose();
  }

  /// Fetches the driver's assigned vehicle.
  Future<void> _fetchDriverVehicle() async {
    debugPrint('_fetchDriverVehicle: Attempting to fetch driver vehicle.');
    try {
      final vehicle = await _driverService.fetchDriverVehicle();
      if (mounted) {
        setState(() {
          _driverVehicle = vehicle;
          _isInService = vehicle?.inService ?? false;
          _isLoading = false;
        });
        debugPrint('_fetchDriverVehicle: Vehicle fetched: ${_driverVehicle?.vehicleRegistration}. In service: $_isInService.');
        if (_isInService) {
          debugPrint('_fetchDriverVehicle: Vehicle is in service, preparing to start location and WebSocket.');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching driver vehicle: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load vehicle data: $e')),
      );
    }
  }

  /// Toggles the vehicle's service status (in/off service).
  Future<void> _toggleServiceStatus(bool newValue) async {
    debugPrint('_toggleServiceStatus: Attempting to change service status to $newValue.');
    if (_driverVehicle == null) {
      debugPrint('_toggleServiceStatus: No vehicle assigned, cannot toggle status.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicle assigned to toggle status.')),
      );
      return;
    }

    setState(() {
      _isInService = newValue;
    });

    try {
      await _driverService.updateVehicleServiceStatus(_driverVehicle!.id, newValue);
      debugPrint('_toggleServiceStatus: Vehicle status updated successfully to: $newValue.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vehicle status updated to: ${newValue ? "In Service" : "Off Service"}')),
      );

      // Control location transmission based on service status
      if (newValue) {
        if (_isLocationInitialized) {
          debugPrint('_toggleServiceStatus: Location initialized, starting transmission.');
          _startLocationAndWebSocketTransmission();
        } else {
          debugPrint('_toggleServiceStatus: Location not yet initialized, will wait for initialization before starting transmission.');
        }
      } else {
        debugPrint('_toggleServiceStatus: Stopping location and WebSocket transmission.');
        _stopLocationAndWebSocketTransmission();
      }
    } catch (e, stackTrace) {
      debugPrint('Error updating service status: $e\n$stackTrace');
      setState(() {
        _isInService = !newValue; // Revert UI if API call fails
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update vehicle status. Please try again. Error: $e')),
      );
    }
  }

  /// Checks and requests location service and permissions.
  Future<void> _initializeLocationAndWebSocket() async {
    debugPrint('_initializeLocationAndWebSocket: Starting.');
    _webSocketUrl = dotenv.env['BACKEND_WS_URL']; // Get WS URL from .env
    if (_webSocketUrl == null) {
      debugPrint('Warning: BACKEND_WS_URL not found in .env. WebSocket functionality will be limited.');
    } else {
      debugPrint('_initializeLocationAndWebSocket: WebSocket URL: $_webSocketUrl');
    }

    await _checkLocationServiceAndPermission();
    debugPrint('_initializeLocationAndWebSocket: Completed location service and permission check.');
  }

  /// Checks and requests location service and permissions using intelligent geoclue.
  Future<void> _checkLocationServiceAndPermission() async {
    debugPrint('_checkLocationServiceAndPermission: Checking location service and permissions.');
    try {
      final locationPoint = await IntelligentLocationService.getCurrentLocationIntelligent();
      
      if (locationPoint != null) {
        debugPrint('_checkLocationServiceAndPermission: Location service enabled: true');
        _isLocationServiceEnabled = true;
        _hasLocationPermission = true;
        
        if (mounted) {
          setState(() {
            _currentLatLng = locationPoint.position;
            _lastLocationPoint = locationPoint;
            _movementStatus = IntelligentLocationService.isMoving ? 'Moving' : 'Stationary';
          });
          debugPrint('_checkLocationServiceAndPermission: Current location obtained: $_currentLatLng.');
        }
      } else {
        debugPrint('_checkLocationServiceAndPermission: Failed to get location from intelligent service');
        _isLocationServiceEnabled = false;
        _hasLocationPermission = false;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to access location services. Please check geoclue configuration.')),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _checkLocationServiceAndPermission: $e\n$stackTrace');
      _isLocationServiceEnabled = false;
      _hasLocationPermission = false;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location: $e')),
        );
      }
      if (mounted) {
        setState(() {
          _currentLatLng = null; // Clear location if error occurs
          _lastLocationPoint = null;
        });
      }
    }
  }

  /// Starts location tracking and WebSocket transmission.
  void _startLocationAndWebSocketTransmission() async {
    debugPrint('_startLocationAndWebSocketTransmission: Attempting to start.');

    if (!_isLocationInitialized) {
      debugPrint('Location initialization not complete yet, deferring transmission start.');
      return;
    }

    await _checkLocationServiceAndPermission();

    if (!_hasLocationPermission) {
      debugPrint('Location permissions are not sufficient after re-check, cannot start tracking. Returning.');
      return;
    }

    if (!_isLocationServiceEnabled) {
      debugPrint('Location services are not enabled after re-check, cannot start tracking. Returning.');
      return;
    }

    if (_driverVehicle == null || _webSocketUrl == null) {
      debugPrint('Cannot start transmission: Vehicle data or WebSocket URL missing. Vehicle: $_driverVehicle, WS URL: $_webSocketUrl. Returning.');
      return;
    }

    await _connectWebSocket();

    if (_isWebSocketConnected && _locationUpdateTimer == null) {
      debugPrint('WebSocket connected and location timer not active. Starting intelligent location updates.');
      
      _startIntelligentLocationTracking();
      debugPrint('Started intelligent location tracking and WebSocket transmission successfully.');
    } else if (!_isWebSocketConnected) {
      debugPrint('WebSocket not connected, cannot start location updates.');
    } else {
      debugPrint('Location timer is already active, not restarting.');
    }
  }

  /// Stops location tracking and WebSocket transmission.
  void _stopLocationAndWebSocketTransmission() {
    debugPrint('_stopLocationAndWebSocketTransmission: Stopping.');
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _disconnectWebSocket();
    debugPrint('Stopped location tracking and WebSocket transmission.');
  }

  /// Connects to the WebSocket server.
  Future<void> _connectWebSocket() async {
    debugPrint('_connectWebSocket: Attempting to connect. URL: $_webSocketUrl, Connected: $_isWebSocketConnected.');
    if (_webSocketUrl == null || _isWebSocketConnected) {
      if (_isWebSocketConnected) debugPrint('_connectWebSocket: WebSocket already connected.');
      return;
    }

    final token = await TokenStorage.getToken();
    final driverId = await TokenStorage.getDriverId();

    if (token == null || driverId == null) {
      debugPrint('Cannot establish WebSocket: Auth token or Driver ID missing. Token: $token, Driver ID: $driverId.');
      return;
    }

    final wsUri = Uri.parse('$_webSocketUrl?token=$token');
    debugPrint('_connectWebSocket: Connecting to WebSocket URI: $wsUri');

    try {
      _locationWsChannel = WebSocketChannel.connect(wsUri);
      await _locationWsChannel!.ready;
      debugPrint('WebSocket connected to $_webSocketUrl');
      if (mounted) {
        setState(() {
          _isWebSocketConnected = true;
        });
      }

      _locationWsChannel!.stream.listen(
        (message) {
          debugPrint('WS Received: $message');
        },
        onDone: () {
          debugPrint('WebSocket disconnected (onDone callback).');
          if (mounted) {
            setState(() {
              _isWebSocketConnected = false;
            });
          }
          if (_isInService) {
             debugPrint('Attempting to reconnect WebSocket...');
                Future.delayed(const Duration(seconds: 5), () {
               _connectWebSocket();
             });
          }
        },
     onError: (error, stackTrace) {
          debugPrint('WebSocket error: $error\n$stackTrace');
          if (mounted) {
            setState(() {
              _isWebSocketConnected = false;
            });
          }
          // Display a more user-friendly error based on HTTP status
          String errorMessage = 'Failed to connect to location service.';
          if (error.toString().contains('401')) {
            errorMessage = 'Authentication failed. Please log in again.';
            // Optionally, navigate to login screen here if 401
          } else if (error.toString().contains('refused')) {
            errorMessage = 'Connection refused. Server might be down.';
          } else if (error.toString().contains('403')) {
            errorMessage = 'Access denied for this user role.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
          // Attempt to reconnect after a delay if still in service
          if (_isInService) {
            debugPrint('Attempting to reconnect WebSocket in 5 seconds due to error...');
            Future.delayed(const Duration(seconds: 5), () {
              _connectWebSocket();
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e, stackTrace) {
      debugPrint('Failed to connect to WebSocket: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _isWebSocketConnected = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to location service: $e')),
      );
       if (_isInService) {
            debugPrint('Attempting to reconnect WebSocket in 5 seconds due to error...');
            Future.delayed(const Duration(seconds: 5), () {
              _connectWebSocket();
            });
          }
    }
  }

  /// Disconnects from the WebSocket server.
  void _disconnectWebSocket() {
    debugPrint('_disconnectWebSocket: Attempting to disconnect.');
    if (_locationWsChannel != null) {
      _locationWsChannel!.sink.close(1000, 'Client disconnected');
      _locationWsChannel = null;
      if (mounted) {
        setState(() {
          _isWebSocketConnected = false;
        });
      }
      debugPrint('WebSocket closed.');
    } else {
      debugPrint('WebSocket channel is null, nothing to disconnect.');
    }
  }

  /// Start intelligent location tracking with dynamic intervals
  void _startIntelligentLocationTracking() {
    _scheduleNextLocationUpdate();
  }

  /// Schedule next location update based on intelligent intervals
  void _scheduleNextLocationUpdate() {
    if (!_isWebSocketConnected || !mounted) return;
    
    final interval = IntelligentLocationService.getRecommendedUpdateInterval();
    debugPrint('Scheduling next location update in ${interval.inSeconds} seconds');
    
    _locationUpdateTimer = Timer(interval, () async {
      await _performIntelligentLocationUpdate();
      _scheduleNextLocationUpdate();
    });
  }

  /// Perform intelligent location update
  Future<void> _performIntelligentLocationUpdate() async {
    try {
      final locationPoint = await IntelligentLocationService.getCurrentLocationIntelligent();
      
      if (locationPoint != null && mounted) {
        setState(() {
          _currentLatLng = locationPoint.position;
          _lastLocationPoint = locationPoint;
          _movementStatus = IntelligentLocationService.isMoving ? 'Moving' : 'Stationary';
        });
        
        _sendLocationViaWebSocket(locationPoint);
        
        debugPrint('Intelligent location update: ${locationPoint.position}, Speed: ${locationPoint.speed?.toStringAsFixed(2)}m/s, Status: $_movementStatus');
      } else {
        debugPrint('No significant location change detected');
      }
    } catch (e) {
      debugPrint('Error in intelligent location update: $e');
    }
  }

  /// Sends location data via WebSocket.
  void _sendLocationViaWebSocket(LocationPoint locationPoint) async {
    if (_locationWsChannel != null && _isWebSocketConnected) {
      final driverId = await TokenStorage.getDriverId();
      if (driverId == null) {
        debugPrint('Driver ID missing, cannot send location.');
        return;
      }

      final locationData = {
        'driver_id': driverId,
        'latitude': locationPoint.position.latitude,
        'longitude': locationPoint.position.longitude,
        'accuracy': locationPoint.accuracy ?? 20.0,
        'speed': locationPoint.speed ?? 0.0,
        'bearing': locationPoint.bearing ?? 0.0,
        'altitude': locationPoint.altitude ?? 0.0,
        'timestamp': locationPoint.timestamp.toIso8601String(),
      };
      try {
        _locationWsChannel!.sink.add(jsonEncode(locationData));
        debugPrint('Sent intelligent location: Lat: ${locationPoint.position.latitude}, Lng: ${locationPoint.position.longitude}, Speed: ${locationPoint.speed?.toStringAsFixed(2)}m/s');
      } catch (e, stackTrace) {
        debugPrint('Error sending location via WebSocket: $e\n$stackTrace');
      }
    } else {
      debugPrint('WebSocket not connected, cannot send location.');
    }
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map & Service Status'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Text(_isInService ? 'In Service' : 'Off Service'),
                    Switch(
                      value: _isInService,
                      onChanged: _toggleServiceStatus,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                    ),
                  ],
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _driverVehicle == null
              ? const Center(
                  child: Text(
                    'No vehicle assigned to this driver.',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : Column(
                  children: [
                    ExpansionTile(
                      initiallyExpanded: _isDetailsExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _isDetailsExpanded = expanded;
                        });
                      },
                      title: Text(
                        _driverVehicle!.vehicleRegistration,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Vehicle No: ${_driverVehicle!.vehicleNo} | Status: ${_isInService ? "In Service" : "Off Service"}',
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Location WS: ${_isWebSocketConnected ? "Connected" : "Disconnected"}'),
                              Text('Location Permission: ${_hasLocationPermission ? "Granted" : "Denied"}'),
                              Text('Movement Status: $_movementStatus'),
                               if (_lastLocationPoint != null) ...[
                                 Text('Speed: ${(_lastLocationPoint!.speed ?? 0.0).toStringAsFixed(1)} m/s'),
                                 Text('Location Accuracy: ${(_lastLocationPoint!.accuracy ?? 0.0).toStringAsFixed(0)} m'),
                                 Text('Last Update: ${_lastLocationPoint!.timestamp.toString().substring(11, 19)}'),
                               ],
                              if (!_hasLocationPermission)
                                ElevatedButton(
                                  onPressed: _checkLocationServiceAndPermission,
                                  child: const Text('Check Location Permissions'),
                                )
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: _currentLatLng == null
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 10),
                                  Text('Waiting for location...'),
                                ],
                              ),
                            )
                          : FlutterMap(
                              options: MapOptions(
                                initialCenter: _currentLatLng!,
                                initialZoom: 15.0,
                              ),
                              children: [
                                // START OF FLUTTER MAPS SECTION
                             TileLayer(
                                    // ESRI World Light Gray Canvas - provides explicit greyscale tiles
                                    // Note the {y}/{x} order and no subdomains.
                                    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                                    // Remove the subdomains line as ESRI does not use them for this service:
                                    // subdomains: const ['a', 'b', 'c', 'd'], // <-- DELETE OR COMMENT OUT THIS LINE
                                    userAgentPackageName: 'com.example.ma3_app',
                                    retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
                                  ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _currentLatLng!,
                                      width: 80,
                                      height: 80,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.blue,
                                        size: 40.0,
                                      ),
                                    ),
                                  ],
                                ),
                                // END OF FLUTTER MAPS SECTION
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }
}