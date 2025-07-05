
class Driver {
  final int id; // This will now correctly store the Driver's specific ID (e.g., 8)
  final String name; // This will be the Driver's name (from the top-level)
  final String email; // This will be the User's email (from nested user_details)
  final String? licenseNumber; // Driver's license number
  final String? phone; // Driver's specific phone number (from top-level)
  final int? saccoId; // Driver's assigned Sacco ID
  final int? vehicleId; // Driver's assigned vehicle ID

  Driver({
    required this.id,
    required this.name,
    required this.email,
    this.licenseNumber,
    this.saccoId,
    this.phone,
    this.vehicleId,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    // Extract top-level driver-specific fields directly
    final int driverId = (json['ID'] as int); // Assuming 'ID' is the Driver's ID
    final String driverName = json['name'] as String; // Driver's name
    final String? driverLicenseNumber = json['license_number'] as String?;
    final String? driverPhone = json['phone'] as String?; // Driver's phone
    final int? driverSaccoId = json['sacco_id'] as int?;
    final int? driverVehicleId = json['vehicle_id'] as int?; // Driver's assigned vehicle

    // Access the nested 'user_details' map for user-specific fields like email
    final Map<String, dynamic>? userDetails = json['user_details'] as Map<String, dynamic>?;
    final String userEmail = userDetails?['email'] as String? ?? ''; // Get email from user_details

    return Driver(
      id: driverId,
      name: driverName,
      email: userEmail,
      licenseNumber: driverLicenseNumber,
      phone: driverPhone,
      saccoId: driverSaccoId,
      vehicleId: driverVehicleId,
    );
  }
}