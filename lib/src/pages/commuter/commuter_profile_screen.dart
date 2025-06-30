// lib/src/screens/commuter_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:ma3_app/src/services/token_storage.dart'; // For logout functionality

class CommuterProfileScreen extends StatelessWidget {
  const CommuterProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center( // Center the content within the tab
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            const Text(
              'Commuter Profile',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Manage your account settings here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () async {
                await TokenStorage.deleteToken(); // Clear token on logout
                if (context.mounted) {
                  // Navigate to login and remove all previous routes from the stack
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
