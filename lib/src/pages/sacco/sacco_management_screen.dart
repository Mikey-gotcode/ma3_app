import 'package:flutter/material.dart';
import 'dart:async'; // Import for Timer
import 'package:latlong2/latlong.dart';

// Import common widgets and services
import 'package:ma3_app/src/widgets/user_card2.dart'; // Assuming UserCard is reusable
import 'package:ma3_app/src/services/sacco_services.dart'; // Ensure this path is correct
import 'package:ma3_app/src/services/auth_service.dart';
import 'package:ma3_app/src/services/token_storage.dart';
//import 'package:ma3_app/src/services/management_services.dart';

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

class _SaccoManagementScreenState extends State<SaccoManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _currentSearchQuery = '';

  // Data fetched from service
  List<RouteData> _allRoutes = [];
  List<Driver> _allDrivers = [];
  List<Vehicle> _allVehicles = [];

  // Filtered lists based on search query
  List<RouteData> _filteredRoutes = [];
  List<Driver> _filteredDrivers = [];
  List<Vehicle> _filteredVehicles = [];

  // Loading states for each tab
  bool _isLoadingRoutes = true;
  bool _isLoadingDrivers = true;
  bool _isLoadingVehicles = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // 3 tabs: Routes, Drivers, Vehicles
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
    setState(() {
      _isLoadingRoutes = true;
    });
    _allRoutes = await SaccoService.fetchRoutesBySacco();
    _filterLists(_currentSearchQuery);
    setState(() {
      _isLoadingRoutes = false;
    });
  }

  Future<void> _fetchDrivers() async {
    setState(() {
      _isLoadingDrivers = true;
    });
    _allDrivers = await SaccoService.fetchDriversBySacco();
    _filterLists(_currentSearchQuery);
    setState(() {
      _isLoadingDrivers = false;
    });
  }

  Future<void> _fetchVehicles() async {
    setState(() {
      _isLoadingVehicles = true;
    });
    _allVehicles = await SaccoService.fetchVehiclesBySacco();
    _filterLists(_currentSearchQuery);
    setState(() {
      _isLoadingVehicles = false;
    });
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

    _filteredRoutes = _allRoutes
        .where(
          (route) =>
              route.name.toLowerCase().contains(lowerCaseQuery) ||
              (route.description.toLowerCase().contains(lowerCaseQuery) ??
                  false),
        )
        .toList();
    _filteredDrivers = _allDrivers.where((driver) {
      // Safely check nullable String fields before calling toLowerCase()
      // Provide an empty string if the field is null to avoid errors.
      final driverName = driver.name
          .toLowerCase(); // Assuming name is always non-null
      final driverEmail = driver.email
          .toLowerCase(); // Assuming email is always non-null
      final driverLicenseNumber =
          driver.licenseNumber?.toLowerCase() ??
          ''; // Handle nullable licenseNumber
      final driverPhone =
          driver.phone?.toLowerCase() ?? ''; // Handle nullable phone

      return driverName.contains(lowerCaseQuery) ||
          driverEmail.contains(lowerCaseQuery) ||
          driverLicenseNumber.contains(lowerCaseQuery) ||
          driverPhone.contains(lowerCaseQuery);
    }).toList();

    _filteredVehicles = _allVehicles
        .where(
          (vehicle) =>
              vehicle.vehicleRegistration.toLowerCase().contains(
                lowerCaseQuery,
              ) ||
              vehicle.vehicleNo.toLowerCase().contains(lowerCaseQuery) ||
              vehicle.vehicleNo.toLowerCase().contains(lowerCaseQuery),
        )
        .toList();
  }

  String _getAddButtonText() {
    switch (_tabController.index) {
      case 0:
        return 'Add Route';
      case 1:
        return 'Add Driver';
      case 2:
        return 'Add Vehicle';
      default:
        return 'Add Item';
    }
  }

  bool _isLoadingCurrentTab() {
    switch (_tabController.index) {
      case 0:
        return _isLoadingRoutes;
      case 1:
        return _isLoadingDrivers;
      case 2:
        return _isLoadingVehicles;
      default:
        return false;
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
                    validator: (value) =>
                        value!.isEmpty ? 'Route Name cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                    ),
                    maxLines: 3,
                  ),
                  TextFormField(
                    controller: geometryController,
                    decoration: const InputDecoration(
                      labelText: 'Route Geometry (GeoJSON LineString)',
                    ),
                    keyboardType: TextInputType.multiline,
                    maxLines: 5,
                    readOnly:
                        true, // Make it read-only as it's filled from map picker
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Geometry is required. Use "View Map" to pick.';
                      }
                      // Basic validation for GeoJSON LineString format.
                      if (!value.contains('"type":"LineString"') ||
                          !value.contains('"coordinates":')) {
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
                  setState(() {
                    // setState on the parent widget to update the dialog's field
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
                    description: descriptionController.text.isNotEmpty
                        ? descriptionController.text
                        : null,
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

    LatLng? pickedLocation;
    String? pickedAddress;
    List<StageModel> stagesToAdd = [];

    void addStageToListHelper(StateSetter setState) {
      if (stageNameController.text.trim().isEmpty) {
        _showSnackBar('Stage name cannot be empty.', isError: true);
        return;
      }
      if (pickedLocation == null) {
        _showSnackBar('Please pick a location on the map.', isError: true);
        return;
      }
      final parsedSeq = int.tryParse(stageSeqController.text.trim());
      if (parsedSeq == null) {
        _showSnackBar('Enter a valid sequence number.', isError: true);
        return;
      }

      stagesToAdd.add(
        StageModel(
          name: stageNameController.text.trim(),
          lat: pickedLocation!.latitude,
          lng: pickedLocation!.longitude,
          seq: parsedSeq,
        ),
      );

      stageNameController.clear();
      stageSeqController.clear();
      setState(() {
        pickedLocation = null;
        pickedAddress = null;
      });

      _showSnackBar('Stage added to list. Add more or Save.');
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add Stages to $routeName',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: stageNameController,
                            decoration: const InputDecoration(
                              labelText: 'Stage Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value!.trim().isEmpty
                                ? 'Stage name required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const StageLocationPickerScreen(),
                                ),
                              );
                              if (result is Map<String, dynamic>) {
                                setState(() {
                                  pickedLocation = LatLng(
                                    result['lat'],
                                    result['lng'],
                                  );
                                  pickedAddress = result['address'];
                                });
                              }
                            },
                            icon: const Icon(Icons.map),
                            label: const Text('Pick Location'),
                          ),
                          if (pickedLocation != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Lat: ${pickedLocation!.latitude.toStringAsFixed(6)}',
                            ),
                            Text(
                              'Lng: ${pickedLocation!.longitude.toStringAsFixed(6)}',
                            ),
                            if (pickedAddress != null)
                              Text('Address: $pickedAddress'),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: stageSeqController,
                            decoration: const InputDecoration(
                              labelText: 'Sequence Number',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value!.trim().isEmpty) {
                                return 'Sequence number required';
                              }
                              if (int.tryParse(value.trim()) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                addStageToListHelper((fn) => fn());
                              }
                            },
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Add Stage to List'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (stagesToAdd.isNotEmpty) ...[
                      Text(
                        'Stages to be saved (${stagesToAdd.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.3,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: stagesToAdd.length,
                          itemBuilder: (ctx, i) {
                            final s = stagesToAdd[i];
                            return ListTile(
                              title: Text('${s.name} (Seq: ${s.seq})'),
                              subtitle: Text(
                                'Lat: ${s.lat.toStringAsFixed(6)}, Lng: ${s.lng.toStringAsFixed(6)}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  stagesToAdd.removeAt(i);
                                  (dialogContext as Element).markNeedsBuild();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (stagesToAdd.isEmpty) {
                              _showSnackBar(
                                'Add at least one stage.',
                                isError: true,
                              );
                              return;
                            }
                            try {
                              final res = await SaccoService.addStagesToRoute(
                                routeId: routeId,
                                stages: stagesToAdd
                                    .map((e) => e.toJson())
                                    .toList(),
                              );
                              if (res['success']) {
                                _showSnackBar(res['message']);
                                Navigator.of(dialogContext).pop();
                                _fetchRoutes();
                              } else {
                                _showSnackBar(res['message'], isError: true);
                              }
                            } catch (e) {
                              _showSnackBar(
                                'Error saving stages.',
                                isError: true,
                              );
                            }
                          },
                          child: const Text('Save All Stages'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                    validator: (value) =>
                        value!.isEmpty ? 'Name cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value!.isEmpty || !value.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => value!.isEmpty || value.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value!.isEmpty ? 'Phone cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: licenseNumberController,
                    decoration: const InputDecoration(
                      labelText: 'License Number',
                    ),
                    validator: (value) => value!.isEmpty
                        ? 'License Number cannot be empty'
                        : null,
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
                  final int? saccoId = await TokenStorage.getSaccoId();
                  final result = await AuthService.signup(
                    name: nameController.text,
                    email: emailController.text,
                    password: passwordController.text,
                    phone: phoneController.text,
                    role: 'driver',
                    driverLicenseNumber: licenseNumberController.text,
                    sacco_id: saccoId,
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
    final int? saccoIdNullable = await TokenStorage.getSaccoId();

    if (saccoIdNullable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sacco ID not found. Please re-login.')),
      );
      return;
    }
    final int saccoId = saccoIdNullable;

    List<Driver> drivers = [];
    List<RouteData> routes = [];
    int? selectedDriverId;
    int? selectedRouteId;

    try {
      drivers = await SaccoService.fetchDriversBySacco();
      routes = await SaccoService.fetchRoutesBySacco();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      return;
    }

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Add New Vehicle',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),

                          // Vehicle Number
                          TextFormField(
                            controller: vehicleNoController,
                            decoration: const InputDecoration(
                              labelText: 'Vehicle Number',
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),

                          // Vehicle Registration
                          TextFormField(
                            controller: vehicleRegistrationController,
                            decoration: const InputDecoration(
                              labelText: 'Registration',
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),

                          // Driver Dropdown
                          DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'Assign Driver',
                            ),
                            items: drivers
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.name),
                                  ),
                                )
                                .toList(),
                            value: selectedDriverId,
                            onChanged: (val) =>
                                setState(() => selectedDriverId = val),
                            validator: (v) =>
                                v == null ? 'Select driver' : null,
                          ),
                          const SizedBox(height: 12),

                          // Route Dropdown
                          DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'Select Route',
                            ),
                            items: routes
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r.id,
                                    child: Text(r.name),
                                  ),
                                )
                                .toList(),
                            value: selectedRouteId,
                            onChanged: (val) =>
                                setState(() => selectedRouteId = val),
                            validator: (v) => v == null ? 'Select route' : null,
                          ),
                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;
                                  try {
                                    final result =
                                        await SaccoService.createVehicle(
                                          vehicleNo: vehicleNoController.text
                                              .trim(),
                                          vehicleRegistration:
                                              vehicleRegistrationController.text
                                                  .trim(),
                                          saccoId: saccoId,
                                          driverId: selectedDriverId!,
                                          routeId: selectedRouteId!,
                                        );
                                    if (!dialogContext.mounted) return;
                                    if (result['success']) {
                                      _showSnackBar(
                                        result['message'] as String,
                                      );
                                      Navigator.of(dialogContext).pop();
                                      _fetchVehicles();
                                    } else {
                                      _showSnackBar(
                                        result['message'] as String,
                                        isError: true,
                                      );
                                    }
                                  } catch (e) {
                                    _showSnackBar(
                                      'Error adding vehicle: \$e',
                                      isError: true,
                                    );
                                  }
                                },
                                child: const Text('Add Vehicle'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 20.0,
              ),
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
                                trailing: '${route.stages.length} stage(s)',
                                icon: Icons.route,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Tapped on Route: ${route.name}',
                                      ),
                                    ),
                                  );
                                },
                                actionButton: TextButton.icon(
                                  icon: const Icon(Icons.add_road),
                                  label: const Text('Add Stages'),
                                  onPressed: () => _showAddStagesDialog(
                                    route.id,
                                    route.name,
                                  ),
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
                                    SnackBar(
                                      content: Text(
                                        'Tapped on Driver: ${driver.name}',
                                      ),
                                    ),
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
            itemCount: _allVehicles.length,
            itemBuilder: (context, index) {
              final vehicle = _allVehicles[index];
              return UserCard(
                title: vehicle.vehicleRegistration, // String
                subtitle: 'Vehicle No: ${vehicle.vehicleNo}', // String
                // FIX: Combine trailing information into a single String
                trailing: 'Service: ${vehicle.inService ? 'In' : 'Out'}\nSacco ID: ${vehicle.saccoId}', // String
                icon: Icons.directions_bus_filled,
                onTap: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Tapped on Vehicle: ${vehicle.vehicleRegistration}',
                        ),
                      ),
                    );
                  }
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

extension on RouteData {
  void operator [](String other) {}
}

extension on Driver {
  void operator [](String other) {}
}
