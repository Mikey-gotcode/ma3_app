// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for text input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State to manage loading indicator
  bool _isLoading = false;

  // Function to handle login process
  void _login() async {
    // Set loading state to true
    setState(() {
      _isLoading = true;
    });

    // Call the login method from AuthService
    final result = await AuthService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    // Set loading state to false
    setState(() {
      _isLoading = false;
    });

    // Show a SnackBar based on the login result
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
      );

      // Get the role from the result
      final String? role = result['role'];

      // Navigate based on the role
      _navigateToRoleScreen(role);

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
      );
    }
  }

  // Helper function to navigate based on role
  void _navigateToRoleScreen(String? role) {
    String route;
    switch (role?.toLowerCase()) { // Use null-aware operator for safety
      case 'commuter':
        route = '/commuter_home';
        break;
      case 'admin':
        route = '/admin_home';
        break;
      case 'sacco':
        route = '/sacco_home';
        break;
      case 'driver':
        route = '/driver_home';
        break;
      default:
        // Fallback for unknown roles or if role is null
        route = '/home'; // Navigate to a generic home page or back to login
        break;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log In'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true, // Hide password
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator() // Show loading indicator
                      : ElevatedButton(
                          onPressed: _login, // Call login function
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50), // Full width button
                          ),
                          child: const Text('Log In'),
                        ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      // Navigate to the signup page
                      Navigator.pushReplacementNamed(context, '/signup');
                    },
                    child: const Text(
                      'Don\'t have an account? Sign Up',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
