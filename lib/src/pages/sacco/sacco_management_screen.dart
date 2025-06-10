import 'package:flutter/material.dart';
import 'dart:async'; // Import for Timer
import 'package:latlong2/latlong.dart';

// Import common widgets and services
import 'package:ma3_app/src/widgets/user_card2.dart'; // Assuming UserCard is reusable
import 'package:ma3_app/src/services/sacco_services.dart'; // Ensure this path is correct
import 'package:ma3_app/src/services/auth_service.dart';
import 'package:ma3_app/src/services/management_services.dart';

// Import models
import 'package:ma3_app/src/models/route_data.dart';
import 'package:ma3_app/src/models/stage.dart';
import 'package:ma3_app/src/models/driver.dart';
import 'package:ma3_app/src/models/vehicle.dart';

// Import the new route picker map screen
import 'package:ma3_app/src/pages/sacco/route_picker_map_screen.dart';
import 'package:ma3_app/src/pages/sacco/stage_location_picker_screen.dart';


class SaccoManagementScreen extends StatefulWidget {
  const SaccoManagementScreen({super.key});

  @override
  State<SaccoManagementScreen> createState() => _SaccoManagementScreenState();
}

class _SaccoManagementScreenState extends State<SaccoManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _currentSearchQuery = '';

  // Data fetched from service
  List<RouteData> _allRoutes = [];
  List<Driver> _allDrivers = [];
  List<ManagementVehicle> _allVehicles = [];

  // Filtered lists based on search query
  List<RouteData> _filteredRoutes = [];
  List<Driver> _filteredDrivers = [];
  List<ManagementVehicle> _filteredVehicles = [];

  // Loading states for each tab
  bool _isLoadingRoutes = true;
  bool _isLoadingDrivers = true;
  bool _isLoadingVehicles = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 tabs: Routes, Drivers, Vehicles
    _searchController.addListener(_onSearchChanged);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _filterLists(_currentSearchQuery); // Re-filter existing data
          _refreshCurrentTabData(); // Re-fetch data for the newly active tab
        });
      }
    });

    // Initial data fetch for all tabs
    _fetchRoutes();
    _fetchDrivers();
    _fetchVehicles();
  }

  // Method to refresh data for the currently active tab
  void _refreshCurrentTabData() {
    switch (_tabController.index) {
      case 0: // Routes tab
        _fetchRoutes();
        break;
      case 1: // Drivers tab
        _fetchDrivers();
        break;
      case 2: // Vehicles tab
        _fetchVehicles();
        break;
    }
  }

  Future<void> _fetchRoutes() async {
    setState(() { _isLoadingRoutes = true; });
    _allRoutes = await SaccoService.fetchMyRoutes();
    _filterLists(_currentSearchQuery);
    setState(() { _isLoadingRoutes = false; });
  }

  Future<void> _fetchDrivers() async {
    setState(() { _isLoadingDrivers = true; });
    _allDrivers = await SaccoService.fetchDriversBySacco();
    _filterLists(_currentSearchQuery);
    setState(() { _isLoadingDrivers = false; });
  }

  Future<void> _fetchVehicles() async {
    setState(() { _isLoadingVehicles = true; });
    _allVehicles = await SaccoService.fetchMyVehicles();
    _filterLists(_currentSearchQuery);
    setState(() { _isLoadingVehicles = false; });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchController.text != _currentSearchQuery) {
        setState(() {
          _currentSearchQuery = _searchController.text;
          _filterLists(_currentSearchQuery);
        });
      }
    });
  }

  void _filterLists(String query) {
    final lowerCaseQuery = query.toLowerCase();

    _filteredRoutes = _allRoutes.where((route) =>
        route.name.toLowerCase().contains(lowerCaseQuery) ||
        (route.description?.toLowerCase().contains(lowerCaseQuery) ?? false)
    ).toList();

    _filteredDrivers = _allDrivers.where((driver) =>
        driver.name.toLowerCase().contains(lowerCaseQuery) ||
        driver.email.toLowerCase().contains(lowerCaseQuery) ||
        driver.licenseNumber.toLowerCase().contains(lowerCaseQuery) ||
        (driver.phone?.toLowerCase().contains(lowerCaseQuery) ?? false)
    ).toList();

    _filteredVehicles = _allVehicles.where((vehicle) =>
        vehicle.registrationNumber.toLowerCase().contains(lowerCaseQuery) ||
        vehicle.model.toLowerCase().contains(lowerCaseQuery) ||
        vehicle.type.toLowerCase().contains(lowerCaseQuery)
    ).toList();
  }

  String _getAddButtonText() {
    switch (_tabController.index) {
      case 0: return 'Add Route';
      case 1: return 'Add Driver';
      case 2: return 'Add Vehicle';
      default: return 'Add Item';
    }
  }

  bool _isLoadingCurrentTab() {
    switch (_tabController.index) {
      case 0: return _isLoadingRoutes;
      case 1: return _isLoadingDrivers;
      case 2: return _isLoadingVehicles;
      default: return false;
    }
  }

  // --- Show SnackBar Helper ---
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // --- Add Route Dialog (Modified) ---
  Future<void> _showAddRouteDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final geometryController = TextEditingController(); // For GeoJSON geometry

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Route'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Route Name'),
                    validator: (value) => value!.isEmpty ? 'Route Name cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description (Optional)'),
                    maxLines: 3,
                  ),
                  TextFormField(
                    controller: geometryController,
                    decoration: const InputDecoration(labelText: 'Route Geometry (GeoJSON LineString)'),
                    keyboardType: TextInputType.multiline,
                    maxLines: 5,
                    readOnly: true, // Make it read-only as it's filled from map picker
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Geometry is required. Use "View Map" to pick.';
                      }
                      // Basic validation for GeoJSON LineString format.
                      if (!value.contains('"type":"LineString"') || !value.contains('"coordinates":')) {
                        return 'Invalid GeoJSON LineString format.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            // NEW: View Map Button
            TextButton(
              child: const Text('View Map'),
              onPressed: () async {
                // Push the map picker screen and await the result
                final String? resultGeometry = await Navigator.push(
                  dialogContext, // Use dialogContext to push over the dialog
                  MaterialPageRoute(
                    builder: (context) => const RoutePickerMapScreen(),
                  ),
                );

                // If geometry was returned, update the controller
                if (resultGeometry != null && dialogContext.mounted) {
                  setState(() { // setState on the parent widget to update the dialog's field
                    geometryController.text = resultGeometry;
                  });
                }
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final result = await SaccoService.createRoute(
                    name: nameController.text,
                    description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                    geometry: geometryController.text, // Send geometry here
                  );
                  if (!dialogContext.mounted) return;
                  if (result['success']) {
                    _showSnackBar(result['message'] as String);
                    Navigator.of(dialogContext).pop();
                    _fetchRoutes(); // Refresh the list
                  } else {
                    _showSnackBar(result['message'] as String, isError: true);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddStagesDialog(int routeId, String routeName) async {
    final formKey = GlobalKey<FormState>();
    final stageNameController = TextEditingController();
    final stageSeqController = TextEditingController();

    LatLng? _pickedLocation;
    String? _pickedAddress;

    // Change the list type to StageModel
    List<StageModel> stagesToAdd = [];

    // Helper function to add a stage to the list
    void _addStageToList(StateSetter setState) {
      if (stageNameController.text.isEmpty ||
          _pickedLocation == null ||
          stageSeqController.text.isEmpty) {
        _showSnackBar('Please fill stage name, pick location, and sequence.', isError: true);
        return;
      }

      stagesToAdd.add(
        // Create an instance of StageModel
        StageModel(
          name: stageNameController.text,
          lat: _pickedLocation!.latitude,
          lng: _pickedLocation!.longitude,
          seq: int.tryParse(stageSeqController.text) ?? 1,
        ),
      );

      // Clear fields for the next stage
      stageNameController.clear();
      stageSeqController.clear();
      setState(() {
        _pickedLocation = null;
        _pickedAddress = null;
      });
      _showSnackBar('Stage added to list. Add more or Save.');
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Add Stages to $routeName'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: stageNameController,
                        decoration: const InputDecoration(labelText: 'Stage Name'),
                        validator: (value) => value!.isEmpty ? 'Stage name cannot be empty' : null,
                      ),
                      const SizedBox(height: 16),
                      // Button to open location picker screen
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StageLocationPickerScreen(),
                            ),
                          );

                          if (result != null && result is Map<String, dynamic>) {
                            setState(() {
                              _pickedLocation = LatLng(result['lat'], result['lng']);
                              _pickedAddress = result['address'];
                            });
                          }
                        },
                        icon: const Icon(Icons.map),
                        label: const Text('Pick Location on Map'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Display selected location details
                      if (_pickedLocation != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Location:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text('Lat: ${_pickedLocation!.latitude.toStringAsFixed(6)}'),
                            Text('Lng: ${_pickedLocation!.longitude.toStringAsFixed(6)}'),
                            if (_pickedAddress != null && _pickedAddress!.isNotEmpty) // Check for empty string too
                              Text('Address: $_pickedAddress'),
                          ],
                        )
                      else
                        const Text('No location selected.', style: TextStyle(fontStyle: FontStyle.italic)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: stageSeqController,
                        decoration: const InputDecoration(labelText: 'Sequence Number'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty || int.tryParse(value) == null ? 'Enter a valid sequence number' : null,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            _addStageToList(setState);
                          }
                        },
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Add Stage to List'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (stagesToAdd.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Stages to be added: ${stagesToAdd.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: stagesToAdd.length,
                              itemBuilder: (context, index) {
                                final stage = stagesToAdd[index]; // This is now a StageModel
                                return ListTile(
                                  title: Text('${stage.name} (Seq: ${stage.seq})'),
                                  subtitle: Text('Lat: ${stage.lat.toStringAsFixed(6)}, Lng: ${stage.lng.toStringAsFixed(6)}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        stagesToAdd.removeAt(index);
                                      });
                                      _showSnackBar('Stage removed from list.');
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
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
                  child: const Text('Save Stages'),
                  onPressed: () async {
                    if (stagesToAdd.isEmpty) {
                      _showSnackBar('No stages to save.', isError: true);
                      return;
                    }

                    // Convert list of StageModel to list of Maps before sending
                    final result = await SaccoService.addStagesToRoute(
                      routeId: routeId,
                      stages: stagesToAdd.map((stage) => stage.toJson()).toList(),
                    );
                    if (!dialogContext.mounted) return;
                    if (result['success']) {
                      _showSnackBar(result['message'] as String);
                      Navigator.of(dialogContext).pop();
                      _fetchRoutes();
                    } else {
                      _showSnackBar(result['message'] as String, isError: true);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }




  // --- Add Driver Dialog (No Change) ---
  Future<void> _showAddDriverDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final licenseNumberController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Driver'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => value!.isEmpty ? 'Name cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value!.isEmpty || !value.contains('@') ? 'Enter a valid email' : null,
                  ),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => value!.isEmpty || value.length < 6 ? 'Password must be at least 6 characters' : null,
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                    validator: (value) => value!.isEmpty ? 'Phone cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: licenseNumberController,
                    decoration: const InputDecoration(labelText: 'License Number'),
                    validator: (value) => value!.isEmpty ? 'License Number cannot be empty' : null,
                  ),
                ],
              ),
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
              child: const Text('Add'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final result = await AuthService.signup(
                    name: nameController.text,
                    email: emailController.text,
                    password: passwordController.text,
                    phone: phoneController.text,
                    role: 'driver',
                    driverLicenseNumber: licenseNumberController.text,
                  );
                  if (!dialogContext.mounted) return;
                  if (result['success']) {
                    _showSnackBar(result['message'] as String);
                    Navigator.of(dialogContext).pop();
                    _fetchDrivers(); // Refresh the list
                  } else {
                    _showSnackBar(result['message'] as String, isError: true);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- Add Vehicle Dialog (No Change) ---
  Future<void> _showAddVehicleDialog() async {
    final formKey = GlobalKey<FormState>();
    final vehicleNoController = TextEditingController();
    final vehicleRegistrationController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Vehicle'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: vehicleNoController,
                    decoration: const InputDecoration(labelText: 'Vehicle Number (e.g., 30B)'),
                    validator: (value) => value!.isEmpty ? 'Vehicle Number cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: vehicleRegistrationController,
                    decoration: const InputDecoration(labelText: 'Vehicle Registration (e.g., KBN 123B)'),
                    validator: (value) => value!.isEmpty ? 'Vehicle Registration cannot be empty' : null,
                  ),
                ],
              ),
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
              child: const Text('Add'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final result = await ManagementService.createVehicle(
                    vehicleNo: vehicleNoController.text,
                    vehicleRegistration: vehicleRegistrationController.text,
                  );
                  if (!dialogContext.mounted) return;
                  if (result['success']) {
                    _showSnackBar(result['message'] as String);
                    Navigator.of(dialogContext).pop();
                    _fetchVehicles(); // Refresh the list
                  } else {
                    _showSnackBar(result['message'] as String, isError: true);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- Modified _onAddItemPressed to show specific dialogs ---
  void _onAddItemPressed() {
    switch (_tabController.index) {
      case 0: // Routes tab
        _showAddRouteDialog();
        break;
      case 1: // Drivers tab
        _showAddDriverDialog();
        break;
      case 2: // Vehicles tab
        _showAddVehicleDialog();
        break;
      default:
        _showSnackBar('Unknown tab selected.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search',
              hintText: 'Search by name, email, registration, etc.',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _currentSearchQuery = '';
                    _filterLists(''); // Clear filters
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            ),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Routes', icon: Icon(Icons.alt_route)),
            Tab(text: 'Drivers', icon: Icon(Icons.person_pin)),
            Tab(text: 'Vehicles', icon: Icon(Icons.directions_bus)),
          ],
        ),
        Expanded(
          child: _isLoadingCurrentTab()
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Routes Tab
                    _filteredRoutes.isEmpty
                        ? const Center(child: Text('No Routes found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _filteredRoutes.length,
                            itemBuilder: (context, index) {
                              final route = _filteredRoutes[index];
                              return UserCard(
                                title: route.name,
                                subtitle: route.description ?? 'No description',
                                trailing: '${route.stages.length} stages',
                                icon: Icons.route,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Tapped on Route: ${route.name}')),
                                  );
                                },
                                actionButton: TextButton.icon(
                                  icon: const Icon(Icons.add_road),
                                  label: const Text('Add Stages'),
                                  onPressed: () => _showAddStagesDialog(route.id, route.name),
                                ),
                              );
                            },
                          ),
                    // Drivers Tab
                    _filteredDrivers.isEmpty
                        ? const Center(child: Text('No Drivers found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _filteredDrivers.length,
                            itemBuilder: (context, index) {
                              final driver = _filteredDrivers[index];
                              return UserCard(
                                title: driver.name,
                                subtitle: driver.email,
                                trailing: driver.licenseNumber,
                                icon: Icons.drive_eta,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Tapped on Driver: ${driver.name}')),
                                  );
                                },
                              );
                            },
                          ),
                    // Vehicles Tab
                    _filteredVehicles.isEmpty
                        ? const Center(child: Text('No Vehicles found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _filteredVehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = _filteredVehicles[index];
                              return UserCard(
                                title: vehicle.registrationNumber,
                                subtitle: '${vehicle.model} (${vehicle.type})',
                                trailing: 'Capacity: ${vehicle.capacity}',
                                icon: Icons.directions_bus_filled,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Tapped on Vehicle: ${vehicle.registrationNumber}')),
                                  );
                                },
                              );
                            },
                          ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _onAddItemPressed,
            icon: const Icon(Icons.add),
            label: Text(_getAddButtonText()),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
