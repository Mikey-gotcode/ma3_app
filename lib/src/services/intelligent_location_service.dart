import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
// Removed geoclue_location_service.dart import as we're using geolocator directly now.
// import 'package:ma3_app/src/services/geoclue_location_service.dart'; // No longer needed

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

  // No longer needed to provide default values here, as the values from geolocator
  // will be directly used. Fallbacks are now handled at the point of sending data.
  // Map<String, dynamic> toJson() {
  //   return {
  //     'latitude': position.latitude,
  //     'longitude': position.longitude,
  //     'timestamp': timestamp.toIso8601String(),
  //     'accuracy': accuracy ?? 20000.0,
  //     'speed': speed ?? 0.0,
  //     'bearing': bearing ?? 0.0,
  //     'altitude': altitude ?? 0.0,
  //   };
  // }
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
  static LocationPoint? _lastLocation; // The last location *accepted* as valid/significant
  static bool _isMoving = false;
  static DateTime? _lastSentTime; // When the last location was *sent* to the backend
  
  // IoT GPS tracking thresholds - Adjusted for smoother, more reliable tracking
  static const double _minAccuracyThreshold = 50.0; // meters - discard points worse than this
  static const double _minDistanceThreshold = 3.0; // meters - minimum movement to consider
  static const double _significantDistanceThreshold = 15.0; // meters - more impactful movement
  static const double _movingSpeedThreshold = 0.5; // m/s (1.8 km/h) - lower to capture slow movement
  static const double _highSpeedThreshold = 15.0; // m/s (54 km/h)
  static const int _maxTimeIntervalSeconds = 5; // Max 45 seconds for any update, even stationary
  static const int _minSendIntervalSeconds = 1; // Minimum interval between sending updates (e.g., 1 second)
  static const double _bearingChangeThreshold = 15.0; // degrees - adjusted for more frequent direction updates

  /// Process a new location point from the device's GPS stream.
  /// Returns the point if it should be sent to the backend, otherwise null.
  static Future<LocationPoint?> processNewLocation(LocationPoint newPoint) async {
    final now = DateTime.now();

    // 1. Initial Point Handling: Always send the first point.
    if (_lastLocation == null) {
      _lastLocation = newPoint;
      _lastSentTime = now;
      _isMoving = newPoint.speed != null && newPoint.speed! > _movingSpeedThreshold;
      return newPoint;
    }

    // 2. Basic Filtering: Discard highly inaccurate points.
    if (newPoint.accuracy != null && newPoint.accuracy! > _minAccuracyThreshold) {
      // If the new point's accuracy is too low, we might discard it,
      // especially if the previous point was much more accurate.
      // This is a simple heuristic. A Kalman filter is more robust.
      if (_lastLocation!.accuracy != null && newPoint.accuracy! > _lastLocation!.accuracy! * 2) {
        print('ILS: Ignoring new point due to poor accuracy (${newPoint.accuracy?.toStringAsFixed(1)}m) compared to last (${_lastLocation!.accuracy?.toStringAsFixed(1)}m).');
        return null;
      }
    }

    // 3. Movement Analysis: Compare with the last *sent* location to determine significance.
    final analysis = _analyzeMovement(_lastLocation!, newPoint);
    
    // Update internal movement state based on current speed
    _isMoving = analysis.speed > _movingSpeedThreshold;
    
    // 4. Decision Logic: Determine if this point should be sent.
    final timeSinceLastSent = _lastSentTime != null ? now.difference(_lastSentTime!).inSeconds : 0;

    // A. Always send if max time interval elapsed (e.g., ensure regular heartbeat)
    if (timeSinceLastSent >= _maxTimeIntervalSeconds) {
      _lastLocation = newPoint; // Update last location to the one being sent
      _lastSentTime = now;
      return LocationPoint(
        position: newPoint.position,
        timestamp: newPoint.timestamp,
        accuracy: newPoint.accuracy,
        speed: analysis.speed,
        bearing: _calculateBearing(_lastLocation!.position, newPoint.position),
        altitude: newPoint.altitude,
      );
    }

    // B. Send if significant movement detected AND minimum send interval elapsed
    if (analysis.isSignificant && timeSinceLastSent >= _minSendIntervalSeconds) {
      _lastLocation = newPoint; // Update last location to the one being sent
      _lastSentTime = now;
      return LocationPoint(
        position: newPoint.position,
        timestamp: newPoint.timestamp,
        accuracy: newPoint.accuracy,
        speed: analysis.speed,
        bearing: _calculateBearing(_lastLocation!.position, newPoint.position),
        altitude: newPoint.altitude,
      );
    }
    
    // 5. If not sent, update _lastLocation for next comparison but return null
    // This ensures _analyzeMovement always compares against the most recent actual location
    // even if it wasn't significant enough to send.
    _lastLocation = newPoint;

    return null; // Don't send this location
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
    // Prevent division by zero and handle very small time differences
    final speed = timeDiff > 0.5 ? distance / timeDiff : 0.0; // Use 0.5s as minimum time diff

    bool isSignificant = false;
    String eventType = 'minor_movement'; // Default event type

    // Prioritize changes in movement state (stopped/started)
    if (_detectMovementStateChange(speed)) {
      isSignificant = true;
      eventType = _isMoving ? 'stopped' : 'started_moving';
    }
    // Significant distance or high speed
    else if (distance >= _significantDistanceThreshold) {
      isSignificant = true;
      eventType = 'significant_movement';
    }
    // Minimum distance for general movement if not already significant
    else if (distance >= _minDistanceThreshold && speed > 0) { // Only consider if there's actual movement
      isSignificant = true;
      eventType = 'movement';
    }
    // High speed override (even if distance threshold not met, though it likely would be)
    else if (speed > _highSpeedThreshold) {
      isSignificant = true;
      eventType = 'high_speed';
    }
    // Direction change for moving vehicles
    else if (_isMoving && _detectDirectionChange(last, current, distance)) {
      isSignificant = true;
      eventType = 'direction_change';
    }
    
    return MovementAnalysis(
      distance: distance,
      speed: speed,
      timeDiff: timeDiff,
      isSignificant: isSignificant,
      eventType: eventType,
    );
  }

  // _shouldSendLocation is now integrated into processNewLocation directly

  /// Detect movement state changes (moving <-> stopped)
  static bool _detectMovementStateChange(double currentSpeed) {
    final wasMoving = _isMoving;
    final isNowMoving = currentSpeed > _movingSpeedThreshold;
    
    return wasMoving != isNowMoving;
  }

  /// Detect significant direction changes
  static bool _detectDirectionChange(LocationPoint last, LocationPoint current, double distance) {
    // Only detect bearing change if vehicle has moved sufficiently
    if (distance < _minDistanceThreshold) return false; 
    
    final lastBearing = last.bearing;
    final currentBearing = _calculateBearing(last.position, current.position);
    
    if (lastBearing == null) return false; // Can't calculate change if no previous bearing

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

  /// Get current movement status
  static bool get isMoving => _isMoving;
  
  /// Get last known location
  static LocationPoint? get lastLocation => _lastLocation;

  /// Reset tracking state (useful when starting/stopping service)
  static void resetState() {
    _lastLocation = null;
    _isMoving = false;
    _lastSentTime = null;
    print('ILS: State reset.');
  }
}