// lib/src/pages/role_pages/sacco_home_page.dart
import 'package:flutter/material.dart';
// Import the new Sacco-specific screens
import 'package:ma3_app/src/pages/sacco/sacco_map_screen.dart';
import 'package:ma3_app/src/pages/sacco/sacco_management_screen.dart';
import 'package:ma3_app/src/pages/sacco/sacco_reports_screen.dart';
import 'package:ma3_app/src/pages/sacco/sacco_profile_screen.dart';

class SaccoHomePage extends StatefulWidget {
  const SaccoHomePage({super.key});

  @override
  State<SaccoHomePage> createState() => _SaccoHomePageState();
}

class _SaccoHomePageState extends State<SaccoHomePage> {
  int _selectedIndex = 0;

  // List of widgets (screens) for each tab
  static const List<Widget> _widgetOptions = <Widget>[
    SaccoMapScreen(),
    SaccoManagementScreen(),
    SaccoReportsScreen(),
    SaccoProfileScreen(),
  ];

  // List of titles for the AppBar
  static const List<String> _appBarTitles = <String>[
    'Sacco Map',
    'Sacco Management',
    'Sacco Reports',
    'Sacco Profile',
  ];

  // Callback for when a bottom navigation item is tapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]), // Dynamic title based on selected tab
        automaticallyImplyLeading: false, // Prevents a back button from appearing
      ),
      body: _widgetOptions.elementAt(_selectedIndex), // Display the selected screen
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Manage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart), // Changed from pie_chart for variety, or use pie_chart if preferred
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex, // Current active tab index
        selectedItemColor: Colors.teal, // Highlight color for selected item
        unselectedItemColor: Colors.grey, // Color for unselected items
        onTap: _onItemTapped, // Callback when an item is tapped
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
        backgroundColor: Colors.white, // Background color of the nav bar
        elevation: 10, // Shadow effect
      ),
    );
  }
}
