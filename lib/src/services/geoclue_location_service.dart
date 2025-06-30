// src/services/geoclue_location_service.dart
import 'package:dbus/dbus.dart';
import 'package:latlong2/latlong.dart';

class GeoclueLocationService {
  static Future<LatLng?> getCurrentLocation() async {
    final client = DBusClient.system();
    DBusRemoteObject? geoClient;
    
    try {
      // First, check if geoclue service is available
      final manager = DBusRemoteObject(
        client,
        name: 'org.freedesktop.GeoClue2',
        path: DBusObjectPath('/org/freedesktop/GeoClue2/Manager'),
      );

      // Call CreateClient to get a client path
      final reply = await manager.callMethod(
        'org.freedesktop.GeoClue2.Manager',
        'CreateClient',
        [],
      );

      final clientPath = reply.returnValues[0].asObjectPath();
      print('GeoclueLocationService: Created client at path: $clientPath');

      geoClient = DBusRemoteObject(
        client,
        name: 'org.freedesktop.GeoClue2',
        path: clientPath,
      );

      // Set the desktop ID to match our .desktop file
      await geoClient.setProperty(
        'org.freedesktop.GeoClue2.Client',
        'DesktopId',
        DBusString('ma3_app'),
      );
      print('GeoclueLocationService: Set DesktopId to ma3_app');

      // Set distance threshold
      await geoClient.setProperty(
        'org.freedesktop.GeoClue2.Client',
        'DistanceThreshold',
        DBusUint32(0),
      );

      // Start the client
      await geoClient.callMethod(
        'org.freedesktop.GeoClue2.Client',
        'Start',
        [],
      );
      print('GeoclueLocationService: Started client');

      // Wait a moment for location to be available
      await Future.delayed(const Duration(milliseconds: 500));

      // Get the current location
      final locationProperty = await geoClient.getProperty(
        'org.freedesktop.GeoClue2.Client',
        'Location',
      );
      
      final locationPath = locationProperty.asObjectPath();
      print('GeoclueLocationService: Got location path: $locationPath');

      // Check if location path is valid (not root path)
      if (locationPath.value == '/') {
        print('GeoclueLocationService: Location path is root, no location available yet');
        return null;
      }

      final location = DBusRemoteObject(
        client,
        name: 'org.freedesktop.GeoClue2',
        path: locationPath,
      );

      final lat = (await location.getProperty(
        'org.freedesktop.GeoClue2.Location',
        'Latitude',
      )).asDouble();

      final lon = (await location.getProperty(
        'org.freedesktop.GeoClue2.Location',
        'Longitude',
      )).asDouble();

      print('GeoclueLocationService: Got location: $lat, $lon');
      return LatLng(lat, lon);
      
    } catch (e) {
      print('Failed to get location via Geoclue: $e');
      return null;
    } finally {
      // Stop the client if it was created
      if (geoClient != null) {
        try {
          await geoClient.callMethod(
            'org.freedesktop.GeoClue2.Client',
            'Stop',
            [],
          );
        } catch (e) {
          print('Error stopping geoclue client: $e');
        }
      }
      await client.close();
    }
  }
}
