import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../src/pages/auth/login_page.dart';
import '../src/pages/auth/signup_page.dart';
import '../src/pages/home/admin_home_page.dart'; // A simple home page after login
import '../src/pages/home/commuter_home_page.dart';
import '../src/pages/home/driver_home_page.dart';
import '../src/pages/home/sacco_home_page.dart';


void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Load the .env file
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Auth App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter', // Using Inter font as per instructions
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0), // Rounded corners for input fields
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0), // Rounded corners for buttons
            ),
            textStyle: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          ),
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // Rounded corners for cards
          ),
          elevation: 4.0,
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/commuter_home': (context) => const CommuterHomePage(),
        '/admin_home': (context) => const AdminHomePage(),
        '/sacco_home': (context) => const SaccoHomePage(),
        '/driver_home': (context) => const DriverHomePage(),
      },
    );
  }
}
