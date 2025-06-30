import 'package:flutter/material.dart';
import 'dart:async'; // Import for Timer
import '../../widgets/user_card.dart';
import '../../models/vehicle.dart';
import '../../models/driver.dart';
import '../../models/commuter.dart';
import '../../models/sacco.dart';
import '../../services/management_services.dart';
import '../../services/auth_service.dart';

// --- Management Screen with Tabs ---
class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _currentSearchQuery = '';

  // Data fetched from service
  List<Sacco> _allSaccos = [];
  List<Commuter> _allCommuters = [];
  List<Driver> _allDrivers = [];
  List<ManagementVehicle> _allVehicles = [];

  // Filtered lists based on search query
  List<Sacco> _filteredSaccos = [];
  List<Commuter> _filteredCommuters = [];
  List<Driver> _filteredDrivers = [];
  List<ManagementVehicle> _filteredVehicles = [];

  // Loading states for each tab
  bool _isLoadingSaccos = true;
  bool _isLoadingCommuters = true;
  bool _isLoadingDrivers = true;
  bool _isLoadingVehicles = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onSearchChanged);

    // Listener to trigger data refresh and filtering when tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        // Only trigger when tab selection is complete
        setState(() {
          _filterLists(_currentSearchQuery); // Re-filter existing data
          _refreshCurrentTabData(); // FIX: Re-fetch data for the newly active tab
        });
      }
    });

    // Initial data fetch for all tabs when the screen is first initialized
    _fetchSaccos();
    _fetchCommuters();
    _fetchDrivers();
    _fetchVehicles();
  }

  // FIX: New method to refresh data for the currently active tab
  void _refreshCurrentTabData() {
    switch (_tabController.index) {
      case 0: // Saccos tab
        _fetchSaccos();
        break;
      case 1: // Commuters tab
        _fetchCommuters();
        break;
      case 2: // Drivers tab
        _fetchDrivers();
        break;
      case 3: // Vehicles tab
        _fetchVehicles();
        break;
    }
  }

  Future<void> _fetchSaccos() async {
    setState(() {
      _isLoadingSaccos = true;
    });
    _allSaccos = await ManagementService.fetchSaccos();
    _filterLists(_currentSearchQuery); // Apply current search query
    setState(() {
      _isLoadingSaccos = false;
    });
  }

  Future<void> _fetchCommuters() async {
    setState(() {
      _isLoadingCommuters = true;
    });
    _allCommuters = await ManagementService.fetchCommuters();
    _filterLists(_currentSearchQuery);
    setState(() {
      _isLoadingCommuters = false;
    });
  }

  Future<void> _fetchDrivers() async {
    setState(() {
      _isLoadingDrivers = true;
    });
    _allDrivers = await ManagementService.fetchDrivers();
    _filterLists(_currentSearchQuery);
    setState(() {
      _isLoadingDrivers = false;
    });
  }

  Future<void> _fetchVehicles() async {
    setState(() {
      _isLoadingVehicles = true;
    });
    _allVehicles = await ManagementService.fetchVehicles();
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

    _filteredSaccos = _allSaccos
        .where(
          (sacco) =>
              sacco.name.toLowerCase().contains(lowerCaseQuery) ||
              sacco.registrationNumber.toLowerCase().contains(lowerCaseQuery) ||
              sacco.email.toLowerCase().contains(lowerCaseQuery),
        )
        .toList();

    _filteredCommuters = _allCommuters
        .where(
          (commuter) =>
              commuter.name.toLowerCase().contains(lowerCaseQuery) ||
              commuter.email.toLowerCase().contains(lowerCaseQuery) ||
              (commuter.phone?.toLowerCase().contains(lowerCaseQuery) ?? false),
        )
        .toList();

     _filteredDrivers = _allDrivers.where((driver) {
    // Safely check nullable String fields before calling toLowerCase()
    // Provide an empty string if the field is null to avoid errors.
    final driverName = driver.name.toLowerCase(); // Assuming name is always non-null
    final driverEmail = driver.email.toLowerCase(); // Assuming email is always non-null
    final driverLicenseNumber = driver.licenseNumber?.toLowerCase() ?? ''; // Handle nullable licenseNumber
    final driverPhone = driver.phone?.toLowerCase() ?? ''; // Handle nullable phone

    return driverName.contains(lowerCaseQuery) ||
           driverEmail.contains(lowerCaseQuery) ||
           driverLicenseNumber.contains(lowerCaseQuery) ||
           driverPhone.contains(lowerCaseQuery);
  }).toList();

    _filteredVehicles = _allVehicles
        .where(
          (vehicle) =>
              vehicle.registrationNumber.toLowerCase().contains(
                lowerCaseQuery,
              ) ||
              vehicle.model.toLowerCase().contains(lowerCaseQuery) ||
              vehicle.type.toLowerCase().contains(lowerCaseQuery),
        )
        .toList();
  }

  String _getAddButtonText() {
    switch (_tabController.index) {
      case 0:
        return 'Add Sacco';
      case 1:
        return 'Add Commuter';
      case 2:
        return 'Add Driver';
      case 3:
        return 'Add Vehicle';
      default:
        return 'Add Item';
    }
  }

  bool _isLoadingCurrentTab() {
    switch (_tabController.index) {
      case 0:
        return _isLoadingSaccos;
      case 1:
        return _isLoadingCommuters;
      case 2:
        return _isLoadingDrivers;
      case 3:
        return _isLoadingVehicles;
      default:
        return false;
    }
  }

  // --- Show SnackBar Helper ---
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // FIX: Mounted check
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // --- Add Commuter Dialog ---
  Future<void> _showAddCommuterDialog() async {
    final formKey = GlobalKey<FormState>(); // FIX: Renamed
    final nameController = TextEditingController(); // FIX: Renamed
    final emailController = TextEditingController(); // FIX: Renamed
    final passwordController = TextEditingController(); // FIX: Renamed
    final phoneController = TextEditingController(); // FIX: Renamed

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Commuter'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey, // FIX: Renamed
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: nameController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) =>
                        value!.isEmpty ? 'Name cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: emailController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value!.isEmpty || !value.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  TextFormField(
                    controller: passwordController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => value!.isEmpty || value.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  TextFormField(
                    controller: phoneController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value!.isEmpty ? 'Phone cannot be empty' : null,
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
                if (formKey.currentState!.validate()) { // FIX: Renamed
                  final result = await AuthService.signup(
                    name: nameController.text, // FIX: Renamed
                    email: emailController.text, // FIX: Renamed
                    password: passwordController.text, // FIX: Renamed
                    phone: phoneController.text, // FIX: Renamed
                    role: 'commuter',
                  );
                  if (!dialogContext.mounted) return; // FIX: Mounted check
                  if (result['success']) {
                    _showSnackBar(result['message'] as String);
                    Navigator.of(dialogContext).pop();
                    _fetchCommuters(); // Refresh the list
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

  // --- Add Sacco Dialog ---
  Future<void> _showAddSaccoDialog() async {
    final formKey = GlobalKey<FormState>(); // FIX: Renamed
    final nameController = TextEditingController(); // FIX: Renamed
    final emailController = TextEditingController(); // FIX: Renamed
    final passwordController = TextEditingController(); // FIX: Renamed
    final phoneController = TextEditingController(); // FIX: Renamed
    final saccoNameController = TextEditingController(); // FIX: Renamed
    final saccoOwnerController = TextEditingController(); // FIX: Renamed

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Sacco'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey, // FIX: Renamed
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: nameController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Company Name (User Name)'),
                    validator: (value) =>
                        value!.isEmpty ? 'Company Name cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: emailController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value!.isEmpty || !value.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  TextFormField(
                    controller: passwordController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => value!.isEmpty || value.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  TextFormField(
                    controller: phoneController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value!.isEmpty ? 'Phone cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: saccoNameController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Sacco Full Name'),
                    validator: (value) =>
                        value!.isEmpty ? 'Sacco Name cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: saccoOwnerController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Sacco Owner Name'),
                    validator: (value) =>
                        value!.isEmpty ? 'Sacco Owner cannot be empty' : null,
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
                if (formKey.currentState!.validate()) { // FIX: Renamed
                  final result = await AuthService.signup(
                    name: nameController.text, // FIX: Renamed
                    email: emailController.text, // FIX: Renamed
                    password: passwordController.text, // FIX: Renamed
                    phone: phoneController.text, // FIX: Renamed
                    role: 'sacco',
                    saccoName: saccoNameController.text, // FIX: Renamed
                    saccoOwner: saccoOwnerController.text, // FIX: Renamed
                  );
                  if (!dialogContext.mounted) return; // FIX: Mounted check
                  if (result['success']) {
                    _showSnackBar(result['message'] as String);
                    Navigator.of(dialogContext).pop();
                    _fetchSaccos(); // Refresh the list
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

  // --- Add Driver Dialog ---
  Future<void> _showAddDriverDialog() async {
    final formKey = GlobalKey<FormState>(); // FIX: Renamed
    final nameController = TextEditingController(); // FIX: Renamed
    final emailController = TextEditingController(); // FIX: Renamed
    final passwordController = TextEditingController(); // FIX: Renamed
    final phoneController = TextEditingController(); // FIX: Renamed
    final licenseNumberController = TextEditingController(); // FIX: Renamed

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Driver'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey, // FIX: Renamed
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: nameController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) =>
                        value!.isEmpty ? 'Name cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: emailController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value!.isEmpty || !value.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  TextFormField(
                    controller: passwordController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => value!.isEmpty || value.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  TextFormField(
                    controller: phoneController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value!.isEmpty ? 'Phone cannot be empty' : null,
                  ),
                  TextFormField(
                    controller: licenseNumberController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'License Number'),
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
                if (formKey.currentState!.validate()) { // FIX: Renamed
                  final result = await AuthService.signup(
                    name: nameController.text, // FIX: Renamed
                    email: emailController.text, // FIX: Renamed
                    password: passwordController.text, // FIX: Renamed
                    phone: phoneController.text, // FIX: Renamed
                    role: 'driver',
                    driverLicenseNumber: licenseNumberController.text, // FIX: Renamed
                  );
                  if (!dialogContext.mounted) return; // FIX: Mounted check
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

  // --- Add Vehicle Dialog ---
  Future<void> _showAddVehicleDialog() async {
    final formKey = GlobalKey<FormState>(); // FIX: Renamed
    final vehicleNoController = TextEditingController(); // FIX: Renamed
    final vehicleRegistrationController = TextEditingController(); // FIX: Renamed

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Vehicle'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey, // FIX: Renamed
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: vehicleNoController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Vehicle Number (e.g., 30B)'),
                    validator: (value) => value!.isEmpty
                        ? 'Vehicle Number cannot be empty'
                        : null,
                  ),
                  TextFormField(
                    controller: vehicleRegistrationController, // FIX: Renamed
                    decoration: const InputDecoration(labelText: 'Vehicle Registration (e.g., KBN 123B)'),
                    validator: (value) => value!.isEmpty
                        ? 'Vehicle Registration cannot be empty'
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
                if (formKey.currentState!.validate()) { // FIX: Renamed
                  final result = await ManagementService.createVehicle(
                    vehicleNo: vehicleNoController.text, // FIX: Renamed
                    vehicleRegistration: vehicleRegistrationController.text, // FIX: Renamed
                  );
                  if (!dialogContext.mounted) return; // FIX: Mounted check
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
      case 0: // Saccos tab
        _showAddSaccoDialog();
        break;
      case 1: // Commuters tab
        _showAddCommuterDialog();
        break;
      case 2: // Drivers tab
        _showAddDriverDialog();
        break;
      case 3: // Vehicles tab
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
            Tab(text: 'Saccos', icon: Icon(Icons.group_work)),
            Tab(text: 'Commuters', icon: Icon(Icons.people)),
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
                    // Saccos Tab
                    _filteredSaccos.isEmpty
                        ? const Center(child: Text('No Saccos found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _filteredSaccos.length,
                            itemBuilder: (context, index) {
                              final sacco = _filteredSaccos[index];
                              return UserCard(
                                title: sacco.name,
                                subtitle: sacco.email,
                                trailing: sacco.registrationNumber,
                                icon: Icons.business,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Tapped on Sacco: ${sacco.name}',
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                    // Commuters Tab
                    _filteredCommuters.isEmpty
                        ? const Center(child: Text('No Commuters found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _filteredCommuters.length,
                            itemBuilder: (context, index) {
                              final commuter = _filteredCommuters[index];
                              return UserCard(
                                title: commuter.name,
                                subtitle: commuter.email,
                                trailing: commuter.phone,
                                icon: Icons.person,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Tapped on Commuter: ${commuter.name}',
                                      ),
                                    ),
                                  );
                                },
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
                                    SnackBar(
                                      content: Text(
                                        'Tapped on Vehicle: ${vehicle.registrationNumber}',
                                      ),
                                    ),
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
