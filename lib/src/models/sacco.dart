import 'package:flutter/material.dart'; // Only if using Material types like IconData or Color
import 'package:intl/intl.dart'; // Import for date formatting

class Sacco {
  final int id;
  final String name;
  final String owner; // New field from JSON
  final String email; // Renamed from contactEmail to match JSON 'email'
  final String phone; // New field from JSON
  final String address; // New field from JSON
  final String registrationNumber; // Still in model, but will be default empty string if not in JSON
  final String createdAt; // Human-readable date string
  final String updatedAt; // Human-readable date string

  Sacco({
    required this.id,
    required this.name,
    required this.owner,
    required this.email,
    required this.phone,
    required this.address,
    required this.registrationNumber, // Kept for consistency, but will default if not in JSON
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create a Sacco object from a JSON map
  factory Sacco.fromJson(Map<String, dynamic> json) {
    // Helper function to format date strings
    String formatDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) {
        return '';
      }
      try {
        final dateTime = DateTime.parse(dateString);
        return DateFormat('dd/MM/yyyy').format(dateTime);
      } catch (e) {
        // Handle parsing errors, e.g., invalid date format
        print('Error parsing date "$dateString": $e');
        return ''; // Return empty string on error
      }
    }

    return Sacco(
      id: json['id'] as int, // Use lowercase 'id' from the JSON response
      name: json['name'] as String,
      owner: json['owner'] as String, // Parse 'owner'
      email: json['email'] as String, // Map 'email' from JSON to 'email' field
      phone: json['phone'] as String, // Parse 'phone'
      address: json['address'] as String, // Parse 'address'
      // 'registrationNumber' is not present in your sample JSON.
      // Providing a default empty string. If it's expected to be dynamic,
      // your backend would need to include it.
      registrationNumber: json['registrationNumber'] as String? ?? '',
      createdAt: formatDate(json['created_at'] as String?), // Format 'created_at'
      updatedAt: formatDate(json['updated_at'] as String?), // Format 'updated_at'
    );
  }
}
