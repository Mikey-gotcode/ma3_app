import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart'; // Import LatLng

class Vehicle {
  // Backend fields from your API response
  final int id; // Changed from String to int to match JSON 'ID'
  final String vehicleNo;
  final String vehicleRegistration;
  final int saccoId;
  final int driverId;
  final bool inService;
  final int routeId;

  // Frontend UI fields (retained as requested)
  LatLng position; // Current position on the map (latitude, longitude)
  Color color;     // Visual color for UI representation
  final IconData icon; // For representing the vehicle visually

  Vehicle({
    required this.id,
    required this.vehicleNo,
    required this.vehicleRegistration,
    required this.saccoId,
    required this.driverId,
    required this.inService,
    required this.routeId,
    // UI-specific fields, initialized with defaults if not provided
    LatLng? position,
    Color? color,
    this.icon = Icons.directions_car, // Default car icon
  }) : // Initialize non-nullable fields with defaults
       position = position ?? const LatLng(-1.286389, 36.817223), // Default Nairobi CBD if no position given
       color = color ?? (inService ? Colors.green : Colors.red); // Derive color from inService status

  // Factory constructor to create a Vehicle object from a JSON map
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    // Extract all fields directly from the top-level JSON map
    final int id = json['ID'] as int;
    final String vehicleNo = json['vehicle_no'] as String;
    final String vehicleRegistration = json['vehicle_registration'] as String;
    final int saccoId = json['sacco_id'] as int;
    final int driverId = json['driver_id'] as int;
    final bool inService = json['in_service'] as bool;
    final int routeId = json['route_id'] as int;

    // UI fields are not typically part of the backend JSON for a vehicle listing.
    // They are either initialized with defaults or would come from a separate
    // tracking endpoint. Here, we set sensible defaults.
    // If you plan to send lat/long from the backend, add them to your JSON
    // and parse them here.
    LatLng defaultPosition = const LatLng(-1.286389, 36.817223); // Default to Nairobi CBD
    Color derivedColor = inService ? Colors.green : Colors.red;

    return Vehicle(
      id: id,
      vehicleNo: vehicleNo,
      vehicleRegistration: vehicleRegistration,
      saccoId: saccoId,
      driverId: driverId,
      inService: inService,
      routeId: routeId,
      position: defaultPosition, // Pass the default or parsed position
      color: derivedColor,      // Pass the derived color
      // icon will use its default value or can be passed if available in JSON
    );
  }

  // Optional: Methods to update UI-specific properties if they are mutable
  void updatePosition(LatLng newPosition) {
    position = newPosition;
  }

  void updateColor(Color newColor) {
    color = newColor;
  }

  // Method to update service status which also updates color
  void setInService(bool status) {
    // This would ideally be called after an API response or local state change
    // If you need 'inService' to be mutable, change 'final bool inService' to 'bool inService'
    // in this class, and update it here. For now, it's final.
    color = status ? Colors.green : Colors.red;
  }
}

// ManagementVehicle class remains unchanged as per your request
class ManagementVehicle {
  final String id;
  final String registrationNumber;
  final String model;
  final String type;
  final int capacity;

  ManagementVehicle({required this.id, required this.registrationNumber, required this.model, required this.type, required this.capacity});

  factory ManagementVehicle.fromJson(Map<String, dynamic> json) {
    return ManagementVehicle(
      id: json['ID'].toString(), // Ensure ID is String for ManagementVehicle
      registrationNumber: json['registrationNumber'],
      model: json['model'],
      type: json['type'],
      capacity: json['capacity'],
    );
  }
}