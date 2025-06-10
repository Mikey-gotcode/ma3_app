import 'package:flutter/material.dart';
import 'package:ma3_app/src/services/token_storage.dart'; // Assuming you have this for logout

class SaccoProfileScreen extends StatelessWidget {
  const SaccoProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, size: 80, color: Colors.teal),
          const SizedBox(height: 20),
          const Text(
            'Sacco Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Manage your account settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () async {
              await TokenStorage.deleteToken(); // Clear token on logout
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}