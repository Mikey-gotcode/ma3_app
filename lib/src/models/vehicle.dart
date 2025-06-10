import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart'; // Import LatLng


class Vehicle {
  final String id;
  LatLng position; // Current position on the map (latitude, longitude)
  final Color color;
  final IconData icon; // For representing the vehicle visually
  // You can add more properties like speed, destination, etc.

  Vehicle({
    required this.id,
    required this.position,
    required this.color,
    this.icon = Icons.directions_car, // Default car icon
  });
}

class ManagementVehicle {
  final String id;
  final String registrationNumber;
  final String model;
  final String type;
  final int capacity;

  ManagementVehicle({required this.id, required this.registrationNumber, required this.model, required this.type, required this.capacity});

  factory ManagementVehicle.fromJson(Map<String, dynamic> json) {
    return ManagementVehicle(
      id: json['ID'],
      registrationNumber: json['registrationNumber'],
      model: json['model'],
      type: json['type'],
      capacity: json['capacity'],
    );
  }
}