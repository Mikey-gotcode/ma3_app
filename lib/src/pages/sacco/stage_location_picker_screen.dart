// lib/src/pages/sacco/stage_location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert'; // For JSON decoding
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For accessing API key
import 'dart:async'; // For Timer debounce

class StageLocationPickerScreen extends StatefulWidget {
  const StageLocationPickerScreen({super.key});

  @override
  State<StageLocationPickerScreen> createState() => _StageLocationPickerScreenState();
}

class _StageLocationPickerScreenState extends State<StageLocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _selectedPoint; // The single point selected for the stage
  String? _selectedAddress; // Human-readable address of the selected point

  bool _isSearching = false; // Loading state for geocoding search
  Timer? _debounce; // Debounce timer for search input

  final String? _orsApiKey = dotenv.env['ORS_API_KEY']; // Get from .env

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  // Debounce logic for text field changes
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (_searchController.text.isNotEmpty) {
        _geocodeLocation(_searchController.text);
      } else {
        // Clear selected point if search bar is empty
        if (mounted) { // Check mounted before setState
          setState(() {
            _selectedPoint = null;
            _selectedAddress = null;
          });
        }
        _showSnackBar('Location search cleared.');
      }
    });
  }

  // Function to perform geocoding using OpenRouteService
  Future<void> _geocodeLocation(String locationName) async {
    if (locationName.isEmpty) return;
    if (_orsApiKey == null || _orsApiKey.isEmpty || _orsApiKey == 'YOUR_ORS_API_KEY') { // Corrected check
      _showSnackBar('OpenRouteService API Key is not configured in .env file.', isError: true);
      return;
    }

    if (!mounted) return; // Pre-check mounted to avoid setState on disposed object
    setState(() { _isSearching = true; });
    _showSnackBar('Searching for "$locationName"...');

    final String url = 'https://api.openrouteservice.org/geocode/search?api_key=$_orsApiKey&text=$locationName';

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          // Access the first feature directly as per ORS JSON structure
          final feature = data['features'][0];
          final List<dynamic> coordinates = feature['geometry']['coordinates'];
          final String address = feature['properties']['label'] ?? 'Unknown Address'; // Get human-readable address

          // ORS returns [longitude, latitude], LatLng expects (latitude, longitude)
          final LatLng foundPoint = LatLng(coordinates[1], coordinates[0]);

          if (mounted) { // Check mounted before setState
            setState(() {
              _selectedPoint = foundPoint;
              _selectedAddress = address;
            });
          }

          // Move map to the newly found point
          _mapController.move(foundPoint, 15.0); // Zoom in a bit more for single point
          _showSnackBar('Location found: $address');
        } else {
          _showSnackBar('Location not found for "$locationName".', isError: true);
          if (mounted) { // Check mounted before setState
            setState(() {
              _selectedPoint = null;
              _selectedAddress = null;
            });
          }
        }
      } else {
        String errorMsg = 'Geocoding failed: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          errorMsg += ' - ${errorData['error']['message'] ?? response.body}';
        } catch (_) {
          errorMsg += ' - ${response.body}';
        }
        _showSnackBar(errorMsg, isError: true);
        if (mounted) { // Check mounted before setState
          setState(() {
            _selectedPoint = null;
            _selectedAddress = null;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error during geocoding: $e', isError: true);
      if (mounted) { // Check mounted before setState
        setState(() {
          _selectedPoint = null;
          _selectedAddress = null;
        });
      }
    } finally {
      if (mounted) setState(() { _isSearching = false; });
    }
  }

  // Allows user to tap on map to select a point
  void _onMapTap(TapPosition tapPosition, LatLng latlng) async {
    if (!mounted) return; // Check mounted before setState
    setState(() {
      _selectedPoint = latlng;
      _selectedAddress = 'Fetching address...'; // Placeholder
    });
    _showSnackBar('Point selected. Fetching address...');

    if (_orsApiKey == null || _orsApiKey.isEmpty || _orsApiKey == 'YOUR_ORS_API_KEY') { // Corrected check
      _showSnackBar('API Key not configured for reverse geocoding.', isError: true);
      return;
    }

    final String url = 'https://api.openrouteservice.org/geocode/reverse?api_key=$_orsApiKey&point.lat=${latlng.latitude}&point.lon=${latlng.longitude}';

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final String address = data['features'][0]['properties']['label'] ?? 'Unknown Address'; // Corrected access
          if (mounted) { // Check mounted before setState
            setState(() {
              _selectedAddress = address;
            });
          }
          _showSnackBar('Address found: $address');
        } else {
          if (mounted) { // Check mounted before setState
            setState(() {
              _selectedAddress = 'No address found for this point.';
            });
          }
          _showSnackBar('No address found for this point.', isError: true);
        }
      } else {
        if (mounted) { // Check mounted before setState
          setState(() {
            _selectedAddress = 'Error fetching address.';
          });
        }
        _showSnackBar('Reverse geocoding failed: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      if (mounted) { // Check mounted before setState
        setState(() {
          _selectedAddress = 'Error fetching address.';
        });
      }
      _showSnackBar('Error during reverse geocoding: $e', isError: true);
    }
  }


  void _submitLocation() {
    if (_selectedPoint != null) {
      // Return the selected LatLng as a Map for consistency with stage data structure
      Navigator.pop(context, {
        'lat': _selectedPoint!.latitude,
        'lng': _selectedPoint!.longitude,
        'address': _selectedAddress, // Optionally return address
      });
    } else {
      _showSnackBar('Please select a location first.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Stage Location'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Pop without result
          },
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(-1.286389, 36.817223), // Use initialCenter
                initialZoom: 13.0, // Use initialZoom
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ma3_app',
                  // retinaMode is deprecated and replaced by FlutterMap's default handling
                ),
                if (_selectedPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: _selectedPoint!,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40.0,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_selectedAddress != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(
                _selectedAddress!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedPoint != null && !_isSearching
                    ? _submitLocation
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Select Location'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
