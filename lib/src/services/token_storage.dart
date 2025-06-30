import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token'; // Key for storing the token
  static const _saccoIdKey = 'sacco_id'; // New key for storing Sacco ID
  static const _driverIdKey = 'driver_id'; // New key for storing Sacco ID

  // Saves the bearer token securely
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Retrieves the bearer token securely
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Deletes the stored token (e.g., on logout)
  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }
  
   // Saves the Sacco ID securely
  static Future<void> saveSaccoId(int saccoId) async {
    await _storage.write(key: _saccoIdKey, value: saccoId.toString()); // Store as string
  }

   // Retrieves the Sacco ID securely
  static Future<int?> getSaccoId() async {
    final String? saccoIdStr = await _storage.read(key: _saccoIdKey);
    return saccoIdStr != null ? int.tryParse(saccoIdStr) : null;
  }

   // Saves the Sacco ID securely
  static Future<void> saveDriverId(int driverId) async {
    await _storage.write(key: _driverIdKey, value: driverId.toString()); // Store as string
  }

   // Retrieves the Sacco ID securely
  static Future<int?> getDriverId() async {
    final String? driverIdStr = await _storage.read(key: _driverIdKey);
    return driverIdStr != null ? int.tryParse(driverIdStr) : null;
  }

   // Deletes the stored token and sacco ID (e.g., on logout)
  static Future<void> clearAllAuthData() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _saccoIdKey);
  }
}
