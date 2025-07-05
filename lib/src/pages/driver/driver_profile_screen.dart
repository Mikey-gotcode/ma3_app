import 'package:flutter/material.dart';
import 'package:ma3_app/src/services/token_storage.dart';
import 'package:ma3_app/src/services/auth_service.dart'; // Corrected import to UserService

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final AuthService _userService = AuthService(); // Using UserService
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers for editing user details
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Controllers for editing Driver details
  final TextEditingController _driverPhoneController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  // Removed: final TextEditingController _saccoIdController = TextEditingController(); // Sacco ID is no longer changeable

  // Controllers for changing password
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _driverPhoneController.dispose();
    _licenseNumberController.dispose();
    // Removed: _saccoIdController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await _userService.getMyProfile();
      setState(() {
        _userProfile = profile;
        // Populate user fields
        _nameController.text = _userProfile?['name'] ?? '';
        _emailController.text = _userProfile?['email'] ?? '';
        _phoneController.text = _userProfile?['phone'] ?? '';

        // Populate Driver fields
        if (_userProfile?['driver'] != null) {
          _driverPhoneController.text = _userProfile!['driver']['phone'] ?? '';
          _licenseNumberController.text = _userProfile!['driver']['license_number'] ?? '';
          // Removed: _saccoIdController.text = (_userProfile!['driver']['sacco_id'] ?? 0).toString();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final Map<String, dynamic> updateData = {};
      // User fields
      if (_nameController.text != (_userProfile?['name'] ?? '')) {
        updateData['name'] = _nameController.text;
      }
      if (_emailController.text != (_userProfile?['email'] ?? '')) {
        updateData['email'] = _emailController.text;
      }
      if (_phoneController.text != (_userProfile?['phone'] ?? '')) {
        updateData['phone'] = _phoneController.text;
      }

      // Driver fields
      if (_userProfile?['driver'] != null) {
        if (_driverPhoneController.text != (_userProfile!['driver']['phone'] ?? '')) {
          updateData['driver_phone'] = _driverPhoneController.text;
        }
        if (_licenseNumberController.text != (_userProfile!['driver']['license_number'] ?? '')) {
          updateData['license_number'] = _licenseNumberController.text;
        }
        // Removed: Logic for updating sacco_id
        // final int? newSaccoId = int.tryParse(_saccoIdController.text);
        // if (newSaccoId != null && newSaccoId != (_userProfile!['driver']['sacco_id'] ?? 0)) {
        //   updateData['sacco_id'] = newSaccoId;
        // }
      }

      if (updateData.isNotEmpty) {
        final updatedProfile = await _userService.updateUserDetails(updateData);
        setState(() {
          _userProfile = updatedProfile;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No changes to update.')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showChangePasswordDialog() async {
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmNewPasswordController.clear();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: _oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current Password'),
                ),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password (min 8 chars)'),
                ),
                TextField(
                  controller: _confirmNewPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm New Password'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Change'),
              onPressed: () async {
                if (_newPasswordController.text.length < 8) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('New password must be at least 8 characters.')),
                  );
                  return;
                }
                if (_newPasswordController.text != _confirmNewPasswordController.text) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match.')),
                  );
                  return;
                }

                try {
                  await _userService.changePassword(
                    _oldPasswordController.text,
                    _newPasswordController.text,
                  );
                  if (mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Failed to change password: ${e.toString()}')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUserProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'Error: $_errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _fetchUserProfile,
                          child: const Text('Retry'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            await TokenStorage.deleteToken();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          },
                          child: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.green,
                              child: Icon(Icons.drive_eta, size: 60, color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _userProfile?['name'] ?? 'N/A',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _userProfile?['role'] ?? 'N/A',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Divider(),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Driver Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Divider(),
                              TextFormField(
                                controller: _driverPhoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Driver Phone',
                                  prefixIcon: Icon(Icons.phone_android),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _licenseNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'License Number',
                                  prefixIcon: Icon(Icons.badge),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Display Sacco Name (read-only) instead of Sacco ID input
                              if (_userProfile?['driver']?['sacco']?['name'] != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.directions_bus, color: Colors.grey),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Assigned Sacco: ${_userProfile!['driver']['sacco']['name']}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 20),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: _updateUserDetails,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Save Changes'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _showChangePasswordDialog,
                              icon: const Icon(Icons.lock),
                              label: const Text('Change Password'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await TokenStorage.deleteToken();
                                if (context.mounted) {
                                  Navigator.pushReplacementNamed(context, '/login');
                                }
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Logout'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
