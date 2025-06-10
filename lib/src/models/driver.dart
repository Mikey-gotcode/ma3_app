// lib/src/models/driver.dart
import 'package:flutter/material.dart'; // Only if using Material types like IconData or Color

class Driver {
  final int id;
  final String name;
  final String email;
  final String licenseNumber;
  final String? phone; // Phone can be nullable

  Driver({required this.id, required this.name, required this.email, required this.licenseNumber, this.phone});

  // Factory constructor to create a Driver object from a JSON map
  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['ID'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      licenseNumber: json['licenseNumber'] as String,
      phone: json['phone'] as String?, // Cast to String?
    );
  }
}
