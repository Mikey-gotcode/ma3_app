// src/services/geoclue_location_service.dart

import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class GeoclueLocationService {
  static Future<LatLng?> getCurrentLocation() async {
    try {
      if (kIsWeb) {
        _logger.w("Location not supported on web.");
        return null;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _logger.w("Location services are disabled.");
        return null;
      }

    // first check & request the *foreground* permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _logger.w("Foreground location permission denied.");
        return null;
      }

      // On Android Q+ you may need to request background separately:
      if (Platform.isAndroid) {
        if (permission == LocationPermission.whileInUse) {
          // prompt again for background if your use‑case requires it
          permission = await Geolocator.requestPermission();
          if (permission != LocationPermission.always) {
            _logger.w("Background location permission not granted.  Some devices require this.");
            // you can still continue with whileInUse only if that suffices
          }
        }
      }

      if (permission == LocationPermission.deniedForever) {
  // takes user to the app’s system settings page
  await Geolocator.openAppSettings();
  return null;
}


      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e, stack) {
      _logger.e('Error getting location', error: e, stackTrace: stack);
      return null;
    }
  }
}
