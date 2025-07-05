import 'package:flutter/material.dart';
import 'package:ma3_app/src/services/token_storage.dart';
import 'package:ma3_app/src/services/auth_service.dart'; // Import the UserService

class SaccoProfileScreen extends StatefulWidget {
  const SaccoProfileScreen({super.key});

  @override
  State<SaccoProfileScreen> createState() => _SaccoProfileScreenState();
}

class _SaccoProfileScreenState extends State<SaccoProfileScreen> {
  final AuthService _userService = AuthService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers for editing user details
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Controllers for editing Sacco details
  final TextEditingController _saccoNameController = TextEditingController();
  final TextEditingController _saccoOwnerController = TextEditingController();
  final TextEditingController _saccoEmailController = TextEditingController();
  final TextEditingController _saccoPhoneController = TextEditingController();

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
    _saccoNameController.dispose();
    _saccoOwnerController.dispose();
    _saccoEmailController.dispose();
    _saccoPhoneController.dispose();
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

        // Populate Sacco fields
        if (_userProfile?['sacco'] != null) {
          _saccoNameController.text = _userProfile!['sacco']['name'] ?? '';
          _saccoOwnerController.text = _userProfile!['sacco']['owner'] ?? '';
          _saccoEmailController.text = _userProfile!['sacco']['email'] ?? '';
          _saccoPhoneController.text = _userProfile!['sacco']['phone'] ?? '';
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

      // Sacco fields
      if (_userProfile?['sacco'] != null) {
        if (_saccoNameController.text != (_userProfile!['sacco']['name'] ?? '')) {
          updateData['sacco_name'] = _saccoNameController.text;
        }
        if (_saccoOwnerController.text != (_userProfile!['sacco']['owner'] ?? '')) {
          updateData['sacco_owner'] = _saccoOwnerController.text;
        }
        if (_saccoEmailController.text != (_userProfile!['sacco']['email'] ?? '')) {
          updateData['sacco_email'] = _saccoEmailController.text;
        }
        if (_saccoPhoneController.text != (_userProfile!['sacco']['phone'] ?? '')) {
          updateData['sacco_phone'] = _saccoPhoneController.text;
        }
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
        title: const Text('Sacco Profile'),
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
                              backgroundColor: Colors.teal,
                              child: Icon(Icons.business, size: 60, color: Colors.white),
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
                                  labelText: 'Contact Person Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Phone',
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
                              const Text('Sacco Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Divider(),
                              TextFormField(
                                controller: _saccoNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Sacco Name',
                                  prefixIcon: Icon(Icons.group),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _saccoOwnerController,
                                decoration: const InputDecoration(
                                  labelText: 'Sacco Owner',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _saccoEmailController,
                                decoration: const InputDecoration(
                                  labelText: 'Sacco Email',
                                  prefixIcon: Icon(Icons.alternate_email),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _saccoPhoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Sacco Phone',
                                  prefixIcon: Icon(Icons.phone_android),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                ),
                                keyboardType: TextInputType.phone,
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
