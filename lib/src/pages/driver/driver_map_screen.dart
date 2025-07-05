import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Import dart:io for WebSocket.connect
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ma3_app/src/models/vehicle.dart';
import 'package:ma3_app/src/services/driver_service.dart';
import 'package:ma3_app/src/services/token_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ma3_app/src/services/intelligent_location_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart'; // Import this for IOWebSocketChannel
import 'package:geolocator/geolocator.dart' as mobile_loc;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Vehicle? _driverVehicle;
  bool _isLoading = true;
  bool _isInService = false;
  bool _isDetailsExpanded = true;

  final DriverService _driverService = DriverService(); 

  LatLng? _currentLatLng;
  Timer? _webSocketPingTimer; 

  bool _isLocationServiceEnabled = false;
  bool _hasLocationPermission = false;
  LocationPoint? _lastLocationPoint;
  String _movementStatus = 'Unknown';

  WebSocketChannel? _locationWsChannel;
  String? _webSocketUrl;
  bool _isWebSocketConnected = false;
  bool _isLocationInitialized = false;

  StreamSubscription<mobile_loc.Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('MapScreen initState: Starting initialization.');
    _fetchDriverVehicle();
    _initializeLocationAndWebSocket().then((_) {
      if (mounted) {
        setState(() => _isLocationInitialized = true);
        if (_isInService) _startLocationAndWebSocketTransmission();
      }
    });
  }

  @override
  void dispose() {
    debugPrint('MapScreen dispose: Cancelling timers, closing WebSocket, and cancelling location stream.');
    _webSocketPingTimer?.cancel();
    _locationWsChannel?.sink.close();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<mobile_loc.Position> _getNativePosition() {
    return mobile_loc.Geolocator.getCurrentPosition(
      desiredAccuracy: mobile_loc.LocationAccuracy.best,
    );
  }

  Future<void> _fetchDriverVehicle() async {
    debugPrint('_fetchDriverVehicle: Fetching driver vehicle.');
    try {
      final vehicle = await _driverService.fetchDriverVehicle();
      if (mounted) {
        setState(() {
          _driverVehicle = vehicle;
          _isInService = vehicle?.inService ?? false;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Error fetching vehicle: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load vehicle data: $e')),
        );
      });
    }
  }

  Future<void> _toggleServiceStatus(bool newValue) async {
    if (_driverVehicle == null) return;
    setState(() => _isInService = newValue);
    try {
      await _driverService.updateVehicleServiceStatus(_driverVehicle!.id, newValue);
      if (newValue) {
        if (_isLocationInitialized) {
          _startLocationAndWebSocketTransmission();
        } else {
          await _initializeLocationAndWebSocket();
          if (_isLocationInitialized) _startLocationAndWebSocketTransmission();
        }
      } else {
        _stopLocationAndWebSocketTransmission();
      }
    } catch (e, st) {
      debugPrint('Error toggling service: $e\n$st');
      if (mounted) setState(() => _isInService = !newValue);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      });
    }
  }

  Future<void> _initializeLocationAndWebSocket() async {
    debugPrint('_initializeLocationAndWebSocket');
    _webSocketUrl = dotenv.env['BACKEND_WS_URL'];
    await _checkLocationServiceAndPermission();
    if (_hasLocationPermission && _isLocationServiceEnabled) {
      final pt = await _getNativePosition();
      if (mounted) { 
        final initialLocationPoint = LocationPoint(
          position: LatLng(pt.latitude, pt.longitude),
          timestamp: DateTime.now(),
          accuracy: pt.accuracy,
          speed: pt.speed,
          bearing: pt.heading,
          altitude: pt.altitude,
        );
        IntelligentLocationService.resetState();
        IntelligentLocationService.processNewLocation(initialLocationPoint);
        setState(() {
          _currentLatLng = initialLocationPoint.position;
          _lastLocationPoint = initialLocationPoint;
          _movementStatus = IntelligentLocationService.isMoving ? 'Moving' : 'Stationary';
        });
      }
    }
  }

  Future<void> _checkLocationServiceAndPermission() async {
    debugPrint('_checkLocationServiceAndPermission');
    bool svc = await mobile_loc.Geolocator.isLocationServiceEnabled();
    if (!svc) {
      debugPrint('Location services disabled');
      if (mounted) {
        setState(() {
          _isLocationServiceEnabled = false;
          _hasLocationPermission = false;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location services are disabled. Please enable them.'), duration: const Duration(seconds: 5)),
        );
      });
      return;
    }
    if (mounted) setState(() => _isLocationServiceEnabled = true);

    var perm = await mobile_loc.Geolocator.checkPermission();
    if (perm == mobile_loc.LocationPermission.denied) {
      perm = await mobile_loc.Geolocator.requestPermission();
    }
    if (perm == mobile_loc.LocationPermission.denied) {
      debugPrint('Permission denied');
      if (mounted) setState(() => _hasLocationPermission = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission denied. Please grant it for tracking.'), duration: const Duration(seconds: 5)),
        );
      });
      return;
    }
    if (perm == mobile_loc.LocationPermission.deniedForever) {
      debugPrint('Permission denied forever; opening settings');
      if (mounted) setState(() => _hasLocationPermission = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission denied permanently. Please enable it in app settings.'), duration: const Duration(seconds: 5)),
        );
      });
      await mobile_loc.Geolocator.openAppSettings();
      return;
    }
    if (mounted) setState(() => _hasLocationPermission = true);
  }

  void _startLocationAndWebSocketTransmission() async {
    debugPrint('_startLocationAndWebSocketTransmission');
    await _checkLocationServiceAndPermission();
    if (!_isLocationInitialized || !_hasLocationPermission || !_isLocationServiceEnabled) {
      debugPrint('Skipping transmission start: Location not initialized or permissions missing.');
      return;
    }
    if (_driverVehicle == null || _webSocketUrl == null) {
      debugPrint('Skipping transmission start: Driver vehicle or WebSocket URL missing.');
      return;
    }
    await _connectWebSocket();
    if (_isWebSocketConnected) {
      _startListeningToLocationUpdates();
    } else {
      debugPrint('WebSocket not connected, cannot start location transmission.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to location server. Please try again.'), duration: Duration(seconds: 3)),
        );
      });
    }
  }

  void _stopLocationAndWebSocketTransmission() {
    debugPrint('_stopLocationAndWebSocketTransmission');
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _disconnectWebSocket();
    IntelligentLocationService.resetState();
  }

Future<void> _connectWebSocket() async {
  if (_webSocketUrl == null) {
    debugPrint('WebSocket URL is null. Cannot connect.');
    return;
  }
  if (_isWebSocketConnected) {
    debugPrint('WebSocket already connected. Skipping reconnection.');
    return;
  }

  final token = await TokenStorage.getToken();
  final drvId = await TokenStorage.getDriverId();
  if (token == null || drvId == null) {
    debugPrint('Auth token or driver ID missing. Cannot connect WebSocket.');
    return;
  }

  final uri = Uri.parse(_webSocketUrl!);
  final wsUri = uri.replace(queryParameters: {
    ...uri.queryParameters,
    'token': token,
  });

  try {
    // Connect (with 10s timeout); ping frames will be sent manually below
    final webSocket = await WebSocket.connect(wsUri.toString())
      .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('WebSocket.connect timeout: Connection took too long.');
        throw TimeoutException('WebSocket connection timed out.');
      });

    // Wrap dart:io WebSocket in a channel
    _locationWsChannel = IOWebSocketChannel(webSocket);

    if (mounted) setState(() => _isWebSocketConnected = true);
    debugPrint('WebSocket connected successfully.');

    // Start a manual ping timer every 40s
    _webSocketPingTimer?.cancel();
    _webSocketPingTimer = Timer.periodic(const Duration(seconds: 40), (_) {
      if (_isWebSocketConnected && _locationWsChannel != null) {
        try {
          _locationWsChannel!.sink.add(jsonEncode({'type': 'ping'}));
          debugPrint('Ping sent');
        } catch (e) {
          debugPrint('Error sending ping: $e');
          _disconnectWebSocket();
        }
      }
    });

    // Listen for incoming messages / handle close & errors
    _locationWsChannel!.stream.listen(
      (_) {
        // ignore incoming data or handle messages here
      },
      onDone: () {
        debugPrint('WebSocket closed by server or normally. Attempting reconnect...');
        if (mounted) {
          setState(() => _isWebSocketConnected = false);
          _webSocketPingTimer?.cancel();
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && _isInService) _connectWebSocket();
          });
        }
      },
      onError: (e) {
        debugPrint('WebSocket error: $e. Attempting reconnect...');
        if (mounted) {
          setState(() => _isWebSocketConnected = false);
          _webSocketPingTimer?.cancel();
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && _isInService) _connectWebSocket();
          });
        }
      },
      cancelOnError: true,
    );
  } catch (e) {
    debugPrint('WebSocket connection error: $e');
    if (mounted) setState(() => _isWebSocketConnected = false);
    _locationWsChannel?.sink.close();
    _locationWsChannel = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WebSocket connection failed: ${e.toString().split(':')[0]}.'),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }
}


  void _disconnectWebSocket() {
    debugPrint('_disconnectWebSocket: Closing WebSocket.');
    _locationWsChannel?.sink.close();
    _webSocketPingTimer?.cancel(); 
    _locationWsChannel = null;
    if (mounted) setState(() => _isWebSocketConnected = false);
  }

  void _startListeningToLocationUpdates() {
    if (_positionStreamSubscription != null) {
      debugPrint('Location stream already active.');
      return;
    }

    debugPrint('Starting Geolocator position stream...');

    final locationSettings = mobile_loc.LocationSettings(
      accuracy: mobile_loc.LocationAccuracy.bestForNavigation,
      distanceFilter: 0, 
    );

    _positionStreamSubscription = mobile_loc.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (mobile_loc.Position position) async {
        if (!mounted) return;

        final newLocationPoint = LocationPoint(
          position: LatLng(position.latitude, position.longitude),
          timestamp: position.timestamp,
          accuracy: position.accuracy,
          speed: position.speed,
          bearing: position.heading,
          altitude: position.altitude,
        );

        final pointToSend = await IntelligentLocationService.processNewLocation(newLocationPoint);

        if (pointToSend != null) {
          if (mounted) {
            setState(() {
              _currentLatLng = pointToSend.position;
              _lastLocationPoint = pointToSend;
              _movementStatus = IntelligentLocationService.isMoving ? 'Moving' : 'Stationary';
            });
          }

          final drvId = await TokenStorage.getDriverId();
          if (drvId != null && _isWebSocketConnected && _locationWsChannel != null) {
            try {
              _locationWsChannel!.sink.add(jsonEncode({
                'driver_id': drvId,
                'latitude': pointToSend.position.latitude,
                'longitude': pointToSend.position.longitude,
                'accuracy': pointToSend.accuracy ?? 20.0,
                'speed': pointToSend.speed ?? 0.0,
                'bearing': pointToSend.bearing ?? 0.0,
                'altitude': pointToSend.altitude ?? 0.0,
                'timestamp': pointToSend.timestamp.toIso8601String(),
              }));
              debugPrint('Location sent: ${pointToSend.position.latitude}, ${pointToSend.position.longitude} | Speed: ${pointToSend.speed?.toStringAsFixed(1)} | Acc: ${pointToSend.accuracy?.toStringAsFixed(0)}');
            } catch (e) {
              debugPrint('Error sending location via WebSocket: $e');
            }
          }
        }
      },
      onError: (e) {
        debugPrint('Geolocator stream error: $e');
        if (mounted) {
          setState(() {
            _hasLocationPermission = false;
            _isLocationServiceEnabled = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Location stream error: $e. Please check permissions and GPS.'), duration: const Duration(seconds: 5)),
            );
          });
          _positionStreamSubscription?.cancel();
          _positionStreamSubscription = null;
        }
      },
      cancelOnError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map & Service Status'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator())),
            )
          else
            Row(
              children: [
                Text(_isInService ? 'In Service' : 'Off Service'),
                Switch(value: _isInService, onChanged: _toggleServiceStatus, activeColor: Colors.green, inactiveThumbColor: Colors.red),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _driverVehicle == null
              ? const Center(child: Text('No vehicle assigned to this driver.', style: TextStyle(fontSize: 18)))
              : Column(
                  children: [
                    ExpansionTile(
                      initiallyExpanded: _isDetailsExpanded,
                      onExpansionChanged: (e) => setState(() => _isDetailsExpanded = e),
                      title: Text(_driverVehicle!.vehicleRegistration, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: Text('Vehicle No: ${_driverVehicle!.vehicleNo} | Status: ${_isInService ? "In Service" : "Off Service"}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Location WS: ${_isWebSocketConnected ? "Connected" : "Disconnected"}'),
                            Text('Location Permission: ${_hasLocationPermission ? "Granted" : "Denied"}'),
                            Text('Location Service Enabled: ${_isLocationServiceEnabled ? "Yes" : "No"}'),
                            Text('Movement Status: $_movementStatus'),
                            if (_lastLocationPoint != null) ...[
                              Text('Speed: ${((_lastLocationPoint!.speed ?? 0) * 3.6).toStringAsFixed(1)} km/h'),
                              Text('Accuracy: ${(_lastLocationPoint!.accuracy ?? 0).toStringAsFixed(0)} m'),
                              Text('Last Update: ${_lastLocationPoint!.timestamp.toIso8601String().substring(11,19)}'),
                              Text('Altitude: ${(_lastLocationPoint!.altitude ?? 0).toStringAsFixed(1)} m'),
                            ],
                            if (!_hasLocationPermission || !_isLocationServiceEnabled)
                              ElevatedButton(onPressed: _checkLocationServiceAndPermission, child: const Text('Check Permissions/Service')),
                          ]),
                        ),
                      ],
                    ),
                    Expanded(
                      child: _currentLatLng == null
                          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text('Waiting for location...')]))
                          : FlutterMap(
                              options: MapOptions(
                                initialCenter: _currentLatLng!,
                                initialZoom: 15,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all & ~InteractiveFlag.doubleTapZoom,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                                  userAgentPackageName: 'com.example.ma3_app',
                                  retinaMode: MediaQuery.of(context).devicePixelRatio > 1,
                                  maxZoom: 16, 
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(point: _currentLatLng!, width: 80, height: 80, child: const Icon(Icons.directions_bus_filled, color: Colors.blue, size: 40)),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }
}