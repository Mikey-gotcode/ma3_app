// lib/src/screens/commuter_home_page.dart
import 'package:flutter/material.dart';
import 'package:ma3_app/src/pages/commuter/commuter_profile_screen.dart'; // Import your SaccoMapScreen
import 'package:ma3_app/src/pages/commuter/commuter_map_screen.dart'; // Import your CommuterProfileScreen

class CommuterHomePage extends StatefulWidget {
  const CommuterHomePage({super.key});

  @override
  State<CommuterHomePage> createState() => _CommuterHomePageState();
}

class _CommuterHomePageState extends State<CommuterHomePage> {
  int _selectedIndex = 0; // Current selected tab index

  // List of widgets to display in the body based on the selected tab.
  // Note: These screens will NOT have their own AppBars, as the parent Scaffold provides one.
  static const List<Widget> _widgetOptions = <Widget>[
    // Tab 0: A simple placeholder for the "Home" content
    _CommuterHomeContent(), 
    // Tab 1: The map screen with live vehicle tracking
    CommuterMapScreen(),
    // Tab 2: The profile screen with logout functionality
    CommuterProfileScreen(),
  ];

  // This method is called when a tab is tapped in the BottomNavigationBar.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commuter Dashboard'), // Main AppBar for the commuter section
        backgroundColor: Colors.teal, // Consistent AppBar color
        automaticallyImplyLeading: false, // Prevents a back button on this main screen
      ),
      body: IndexedStack( // IndexedStack preserves the state of each tab when switching
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal, // Color for the selected icon/label
        unselectedItemColor: Colors.grey, // Color for unselected icons/labels
        onTap: _onItemTapped, // Callback when a tab is tapped
        backgroundColor: Colors.white, // Background color of the navigation bar
        type: BottomNavigationBarType.fixed, // Ensures all labels are always visible
      ),
    );
  }
}

// A simple widget for the "Home" tab content
class _CommuterHomeContent extends StatelessWidget {
  const _CommuterHomeContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_bus, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'Welcome, Commuter!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Navigate through the app using the tabs below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                // You can add more specific commuter-related content here
                // For example, a button to quickly go to the map:
                ElevatedButton.icon(
                  onPressed: () {
                    // This will switch to the Map tab
                    final commuterHomePageState = context.findAncestorStateOfType<_CommuterHomePageState>();
                    commuterHomePageState?._onItemTapped(1); // Index 1 is the Map tab
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('View Live Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
