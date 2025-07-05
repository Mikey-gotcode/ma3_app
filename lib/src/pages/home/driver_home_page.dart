import 'package:flutter/material.dart';
import 'package:ma3_app/src/pages/driver/driver_map_screen.dart'; // Import the new MapScreen
import 'package:ma3_app/src/pages/driver/driver_profile_screen.dart'; 

// Placeholder screens for other tabs
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Earnings Screen Content', style: TextStyle(fontSize: 24)));
  }
}



class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  int _selectedIndex = 0; // Current selected tab index

  static const List<Widget> _widgetOptions = <Widget>[
    MapScreen(),      // Your map screen with the toggle
    EarningsScreen(), // Placeholder for earnings
    DriverProfileScreen(),  // Placeholder for profile
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar is now part of each screen, or you can keep it here
      // if you want a consistent app bar across all main screens.
      // For simplicity, MapScreen has its own AppBar for the toggle.
      // If you want a global app bar for DriverHomePage, you can uncomment this
      // and remove the app bars from individual screens.
      // appBar: AppBar(
      //   title: const Text('Driver Dashboard'),
      //   automaticallyImplyLeading: false,
      // ),
      body: _widgetOptions.elementAt(_selectedIndex), // Display the selected screen
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wallet),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange[800],
        onTap: _onItemTapped,
      ),
    );
  }
}