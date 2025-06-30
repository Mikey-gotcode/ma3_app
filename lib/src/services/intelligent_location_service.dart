// src/services/intelligent_location_service.dart
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:ma3_app/src/services/geoclue_location_service.dart';

class LocationPoint {
  final LatLng position;
  final DateTime timestamp;
  final double? accuracy;
  final double? speed;
  final double? bearing;
  final double? altitude;

  LocationPoint({
    required this.position,
    required this.timestamp,
    this.accuracy,
    this.speed,
    this.bearing,
    this.altitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy ?? 20000.0,
      'speed': speed ?? 0.0,
      'bearing': bearing ?? 0.0,
      'altitude': altitude ?? 0.0,
    };
  }
}

class MovementAnalysis {
  final double distance;
  final double speed;
  final double timeDiff;
  final bool isSignificant;
  final String eventType;

  MovementAnalysis({
    required this.distance,
    required this.speed,
    required this.timeDiff,
    required this.isSignificant,
    required this.eventType,
  });
}

class IntelligentLocationService {
  static LocationPoint? _lastLocation;
  static bool _isMoving = false;
  static DateTime? _lastSentTime;
  
  // IoT GPS tracking thresholds
  static const double _minDistanceThreshold = 5.0; // meters
  static const double _significantDistanceThreshold = 50.0; // meters
  static const double _movingSpeedThreshold = 1.0; // m/s (3.6 km/h)
  static const double _highSpeedThreshold = 10.0; // m/s (36 km/h)
  static const int _maxTimeIntervalSeconds = 300; // 5 minutes
  static const int _minTimeIntervalSeconds = 10; // 10 seconds for high-speed
  static const double _bearingChangeThreshold = 30.0; // degrees

  /// Get current location with intelligent filtering
  static Future<LocationPoint?> getCurrentLocationIntelligent() async {
    try {
      final position = await GeoclueLocationService.getCurrentLocation();
      if (position == null) return null;

      final now = DateTime.now();
      final locationPoint = LocationPoint(
        position: position,
        timestamp: now,
        accuracy: 20.0, // Assume good accuracy from geoclue
      );

      // If this is the first location, return it
      if (_lastLocation == null) {
        _lastLocation = locationPoint;
        _lastSentTime = now;
        return locationPoint;
      }

      // Analyze movement
      final analysis = _analyzeMovement(_lastLocation!, locationPoint);
      
      // Update internal state
      _isMoving = analysis.speed > _movingSpeedThreshold;
      
      // Determine if we should send this location
      if (_shouldSendLocation(analysis, now)) {
        _lastLocation = locationPoint;
        _lastSentTime = now;
        
        // Add calculated speed and bearing to the location point
        return LocationPoint(
          position: position,
          timestamp: now,
          accuracy: 20.0,
          speed: analysis.speed,
          bearing: _calculateBearing(_lastLocation!.position, position),
        );
      }

      return null; // Don't send this location
    } catch (e) {
      print('Error in getCurrentLocationIntelligent: $e');
      return null;
    }
  }

  /// Analyze movement between two location points
  static MovementAnalysis _analyzeMovement(LocationPoint last, LocationPoint current) {
    final distance = _calculateDistance(
      last.position.latitude, 
      last.position.longitude,
      current.position.latitude, 
      current.position.longitude
    );
    
    final timeDiff = current.timestamp.difference(last.timestamp).inSeconds.toDouble();
    final speed = timeDiff > 0 ? distance / timeDiff : 0.0;
    
    // Determine if movement is significant
    bool isSignificant = false;
    String eventType = 'minor_movement';
    
    // Time-based rules
    if (timeDiff > _maxTimeIntervalSeconds) {
      isSignificant = true;
      eventType = 'time_interval';
    }
    // Distance-based rules
    else if (distance > _significantDistanceThreshold) {
      isSignificant = true;
      eventType = 'significant_movement';
    }
    // Speed-based rules
    else if (speed > _highSpeedThreshold) {
      isSignificant = true;
      eventType = 'high_speed';
    }
    // Movement state change
    else if (_detectMovementStateChange(speed)) {
      isSignificant = true;
      eventType = _isMoving ? 'stopped' : 'started_moving';
    }
    // Direction change
    else if (_detectDirectionChange(last, current, distance)) {
      isSignificant = true;
      eventType = 'direction_change';
    }
    // Minimum distance threshold
    else if (distance > _minDistanceThreshold) {
      isSignificant = true;
      eventType = 'movement';
    }
    
    return MovementAnalysis(
      distance: distance,
      speed: speed,
      timeDiff: timeDiff,
      isSignificant: isSignificant,
      eventType: eventType,
    );
  }

  /// Determine if location should be sent based on analysis and timing
  static bool _shouldSendLocation(MovementAnalysis analysis, DateTime now) {
    // Always send if significant movement
    if (analysis.isSignificant) return true;
    
    // Don't send if we sent something very recently (unless high speed)
    if (_lastSentTime != null) {
      final timeSinceLastSent = now.difference(_lastSentTime!).inSeconds;
      if (timeSinceLastSent < _minTimeIntervalSeconds && analysis.speed < _highSpeedThreshold) {
        return false;
      }
    }
    
    return false;
  }

  /// Detect movement state changes (moving <-> stopped)
  static bool _detectMovementStateChange(double currentSpeed) {
    final wasMoving = _isMoving;
    final isNowMoving = currentSpeed > _movingSpeedThreshold;
    
    return wasMoving != isNowMoving;
  }

  /// Detect significant direction changes
  static bool _detectDirectionChange(LocationPoint last, LocationPoint current, double distance) {
    if (distance < 10) return false; // Need meaningful movement to calculate bearing
    
    final lastBearing = last.bearing ?? 0.0;
    final currentBearing = _calculateBearing(last.position, current.position);
    
    final bearingDiff = (currentBearing - lastBearing).abs();
    final adjustedDiff = bearingDiff > 180 ? 360 - bearingDiff : bearingDiff;
    
    return adjustedDiff > _bearingChangeThreshold;
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Earth's radius in meters
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// Calculate bearing between two points
  static double _calculateBearing(LatLng from, LatLng to) {
    final double dLon = (to.longitude - from.longitude) * math.pi / 180;
    final double lat1Rad = from.latitude * math.pi / 180;
    final double lat2Rad = to.latitude * math.pi / 180;
    
    final double y = math.sin(dLon) * math.cos(lat2Rad);
    final double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    
    final double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360; // Normalize to 0-360 degrees
  }

  /// Get recommended update interval based on current movement state
  static Duration getRecommendedUpdateInterval() {
    if (_lastLocation == null) {
      return const Duration(seconds: 5); // Initial frequent updates
    }
    
    final analysis = _analyzeMovement(_lastLocation!, _lastLocation!);
    
    if (analysis.speed > _highSpeedThreshold) {
      return const Duration(seconds: 10); // High speed: frequent updates
    } else if (_isMoving) {
      return const Duration(seconds: 10); // Moving: moderate updates
    } else {
      return const Duration(seconds: 10); // Stationary: infrequent updates
    }
  }

  /// Reset tracking state (useful when starting/stopping service)
  static void resetState() {
    _lastLocation = null;
    _isMoving = false;
    _lastSentTime = null;
  }

  /// Get current movement status
  static bool get isMoving => _isMoving;
  
  /// Get last known location
  static LocationPoint? get lastLocation => _lastLocation;
}
