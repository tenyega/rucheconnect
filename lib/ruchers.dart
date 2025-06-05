import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// Import UserRole enum from home page
enum UserRole {
  admin,
  apiculteur,
  unknown
}

// Model class for apiculteur with rucher info
class ApiculteurWithRuchers {
  final String id;
  final String nom;
  final String prenom;
  final List<RucherInfo> ruchers;
  bool isExpanded;

  ApiculteurWithRuchers({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.ruchers,
    this.isExpanded = false,
  });
}

// Model class for simplified rucher info
class RucherInfo {
  final String id;
  final String address;
  final String description;
  final String picUrl;
  final int rucheCount;
  final List<RucheInfo> ruches;
  final int alertCount;
  bool isExpanded;

  RucherInfo({
    required this.id,
    required this.address,
    required this.description,
    required this.picUrl,
    required this.rucheCount,
    required this.ruches,
    this.alertCount = 0,
    this.isExpanded = false,
  });
}

class RucherApiculteurView extends StatefulWidget {
  const RucherApiculteurView({Key? key}) : super(key: key);

  @override
  State<RucherApiculteurView> createState() => _RucherApiculteurViewState();
}

// Model class for ruche info
class RucheInfo {
  final String id;
  final String rucherId;
  final String apiculteurId;
  final Map<String, RucheDataPoint> dataPoints;
  bool isExpanded;

  RucheInfo({
    required this.id,
    required this.rucherId,
    required this.apiculteurId,
    required this.dataPoints,
    this.isExpanded = false,
  });

  bool get hasActiveAlert {
    final latestData = getLatestDataPoint();
    if (latestData == null) return false;

    final alert = latestData.alert ?? 0;
    final couvercle = latestData.couvercle ?? 0;

    // Alert condition: alerts are enabled AND lid is open
    return (alert == 1 && couvercle == 1);
  }

  RucheDataPoint? getLatestDataPoint() {
    if (dataPoints.isEmpty) return null;

    String? bestKey;
    RucheDataPoint? bestDataPoint;
    DateTime? latestTimestamp;

    // Sort entries by timestamp, then by key as tie-breaker
    var sortedEntries = dataPoints.entries.toList();
    sortedEntries.sort((a, b) {
      // First, compare by timestamp
      int timestampComparison = a.value.timestamp.compareTo(b.value.timestamp);
      if (timestampComparison != 0) {
        return timestampComparison;
      }

      // If timestamps are equal, use the key as tie-breaker (higher key wins)
      int aKey = int.tryParse(a.key) ?? 0;
      int bKey = int.tryParse(b.key) ?? 0;
      return aKey.compareTo(bKey);
    });

    // Return the last (most recent) entry
    if (sortedEntries.isNotEmpty) {
      return sortedEntries.last.value;
    }

    return null;
  }

  String? getLatestDataPointKey() {
    if (dataPoints.isEmpty) return null;

    String? bestKey;
    DateTime? latestTimestamp;

    // Sort entries by timestamp, then by key as tie-breaker
    var sortedEntries = dataPoints.entries.toList();
    sortedEntries.sort((a, b) {
      // First, compare by timestamp
      int timestampComparison = a.value.timestamp.compareTo(b.value.timestamp);
      if (timestampComparison != 0) {
        return timestampComparison;
      }

      // If timestamps are equal, use the key as tie-breaker (higher key wins)
      int aKey = int.tryParse(a.key) ?? 0;
      int bKey = int.tryParse(b.key) ?? 0;
      return aKey.compareTo(bKey);
    });

    // Return the key of the last (most recent) entry
    if (sortedEntries.isNotEmpty) {
      return sortedEntries.last.key;
    }

    return null;
  }

  bool get alertActive {
    final latestData = getLatestDataPoint();
    if (latestData == null) return false;

    // Alert is "active/enabled" when the alert flag is 1
    // This doesn't mean there's currently an alert, just that alerts are enabled
    return (latestData.alert == 1);
  }
}

// Data model for individual ruche data points
class RucheDataPoint {
  final DateTime timestamp;
  final int temperature;
  final int humidity;
  final int? couvercle; // 0 = closed, 1 = open
  final int? alert; // 0 = no alert, 1 = alert

  RucheDataPoint({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.couvercle,
    required this.alert,
  });

  factory RucheDataPoint.fromString(String dataString) {
    final parts = dataString.split('/');
    String dateTimeStr = parts[0];

    // Remove the leading '47' which seems to be a prefix in your data
    if (dateTimeStr.startsWith('47')) {
      dateTimeStr = dateTimeStr.substring(2);
    }

    // Handle different timestamp formats
    DateTime timestamp;
    try {
      if (dateTimeStr.endsWith('Z') && !dateTimeStr.contains('.')) {
        // Format like "2025-05-12T20:38:10Z" - add milliseconds for consistency
        dateTimeStr = dateTimeStr.replaceAll('Z', '.000Z');
      }
      timestamp = DateTime.parse(dateTimeStr);
    } catch (e) {
      print('Error parsing timestamp "$dateTimeStr": $e');
      // Fallback to current time if parsing fails
      timestamp = DateTime.now();
    }

    final int temperature = int.tryParse(parts[1]) ?? 0;
    final int humidity = int.tryParse(parts[2]) ?? 0;
    final int couvercle = parts.length > 3 ? (int.tryParse(parts[3]) ?? 0) : 0;
    final int alert = parts.length > 4 ? (int.tryParse(parts[4]) ?? 0) : 0;

    return RucheDataPoint(
      timestamp: timestamp,
      temperature: temperature,
      humidity: humidity,
      couvercle: couvercle,
      alert: alert,
    );
  }
}

class _RucherApiculteurViewState extends State<RucherApiculteurView> {
  final DatabaseReference _apiculteursRef = FirebaseDatabase.instance.ref('apiculteurs');
  List<ApiculteurWithRuchers> _apiculteurs = [];
  bool _isLoading = true;
  UserRole _userRole = UserRole.unknown;
  String _currentApiculteurId = '';

  // Map to keep track of which apiculteur a rucher belongs to
  Map<String, String> _rucherToApiculteurMap = {};

  @override
  void initState() {
    super.initState();
    _checkUserRole();

    // Set up listener for real-time updates
    _apiculteursRef.onValue.listen((event) {
      _loadApiculteursFromSnapshot(event.snapshot);
    });
  }

  // Helper method to load ruches data for a rucher
  List<RucheInfo> _loadRuchesForRucher(Map<dynamic, dynamic> rucherData, String rucherId, String apiculteurId) {
    List<RucheInfo> ruches = [];

    rucherData.forEach((key, value) {
      if (key.toString().startsWith('ruche') && value is Map<dynamic, dynamic>) {
        // Parse ruche data points
        Map<String, RucheDataPoint> dataPoints = {};

        value.forEach((dataKey, dataValue) {
          if (dataValue is String && dataValue.contains('/')) {
            try {
              dataPoints[dataKey.toString()] = RucheDataPoint.fromString(dataValue);
            } catch (e) {
              print('Error parsing ruche data: $e');
            }
          }
        });

        ruches.add(RucheInfo(
          id: key.toString(),
          rucherId: rucherId,
          apiculteurId: apiculteurId,
          dataPoints: dataPoints,
        ));
      }
    });

    return ruches;
  }

  // Get total active alerts across all ruchers - IMPROVED VERSION
  bool _hasActiveAlert(RucheInfo ruche) {
    // Use the new hasActiveAlert getter from RucheInfo
    return ruche.hasActiveAlert;
  }

  int _getTotalActiveAlerts() {
    int totalAlerts = 0;
    for (var apiculteur in _apiculteurs) {
      for (var rucher in apiculteur.ruchers) {
        for (var ruche in rucher.ruches) {
          if (_hasActiveAlert(ruche)) {
            totalAlerts++;
          }
        }
      }
    }
    return totalAlerts;
  }

  // Count alerts for a specific rucher by checking its ruches - IMPROVED VERSION
  int _countRucherAlerts(Map<dynamic, dynamic> rucherData) {
    int alertCount = 0;

    print('=== CHECKING RUCHER FOR ALERTS ===');

    rucherData.forEach((key, value) {
      String keyStr = key.toString();

      // Check if this is a ruche entry
      if (keyStr.startsWith('ruche') && value is Map<dynamic, dynamic>) {
        print('Analyzing ruche $keyStr...');

        bool hasAlert = false;

        // Look through all entries in this ruche
        value.forEach((entryKey, entryValue) {
          print('  Raw entry: $entryKey = $entryValue (type: ${entryValue.runtimeType})');

          // Check if the entry value is a string with the expected format
          if (entryValue is String && entryValue.contains('/')) {
            print('  Found data entry: $entryKey = $entryValue');

            // Split the string by '/' to get the parts
            List<String> parts = entryValue.split('/');
            print('  Split parts: $parts (length: ${parts.length})');

            // Check if we have at least 5 parts
            if (parts.length >= 5) {
              String alertValue = parts.last.trim();
              print('    Alert value: "$alertValue" (length: ${alertValue.length})');
              print('    Alert value bytes: ${alertValue.codeUnits}');

              // Check if alert value indicates an active alert
              if (alertValue == '1') {
                hasAlert = true;
                print('    >>> ALERT DETECTED in ruche $keyStr!');
              } else {
                print('    No alert - value is: "$alertValue"');
              }
            } else {
              print('    Insufficient parts - expected at least 5, got ${parts.length}');
            }
          } else if (entryValue is String) {
            print('  String entry without "/" separator: $entryValue');
          } else {
            print('  Non-string entry: $entryValue');
          }
        });

        if (hasAlert) {
          alertCount++;
          print('  FINAL: Ruche $keyStr HAS ALERT');
        } else {
          print('  FINAL: Ruche $keyStr has no alert');
        }
      }
    });

    print('Total alerts for this rucher: $alertCount');
    print('=== END ALERT CHECK ===');
    return alertCount;
  }

  Future<void> _checkUserRole() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && currentUser.email != null) {
      final String email = currentUser.email!;

      // Check if the user is an admin (email is test@gmail.com)
      if (email == 'test@gmail.com') {
        setState(() {
          _userRole = UserRole.admin;
        });
        await _loadApiculteurs();
      }
      // Check if the user is an apiculteur (email starts with api and ends with @email.com)
      else if (email.startsWith('api') && email.endsWith('@email.com')) {
        setState(() {
          _userRole = UserRole.apiculteur;
        });
        await _loadCurrentApiculteur(email);
      }
      else {
        // If not admin or apiculteur, set to unknown role
        setState(() {
          _userRole = UserRole.unknown;
          _isLoading = false;
        });
      }
    } else {
      // User not authenticated
      setState(() {
        _userRole = UserRole.unknown;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentApiculteur(String email) async {
    try {
      final snapshot = await _apiculteursRef.get();
      if (snapshot.exists && snapshot.value != null) {
        final map = snapshot.value as Map<dynamic, dynamic>;

        // Find the current apiculteur by email
        map.forEach((key, value) {
          if (key.toString().startsWith('api') &&
              value is Map<dynamic, dynamic> &&
              value['email'] == email) {
            _currentApiculteurId = key.toString();
          }
        });

        // Load only the current apiculteur's ruchers
        if (_currentApiculteurId.isNotEmpty) {
          final specificApiculteurRef = _apiculteursRef.child(_currentApiculteurId);
          final apiculteurSnapshot = await specificApiculteurRef.get();
          if (apiculteurSnapshot.exists && apiculteurSnapshot.value != null) {
            _loadSpecificApiculteurFromSnapshot(apiculteurSnapshot, _currentApiculteurId);
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadApiculteurs() async {
    try {
      final snapshot = await _apiculteursRef.get();
      _loadApiculteursFromSnapshot(snapshot);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
    }
  }

  // Helper method to sort ruchers by their ID (rucher_001, rucher_002, etc.)
  List<RucherInfo> _sortRuchers(List<RucherInfo> ruchers) {
    ruchers.sort((a, b) {
      // Extract the numeric part from rucher IDs for proper sorting
      final aMatch = RegExp(r'rucher_(\d+)').firstMatch(a.id);
      final bMatch = RegExp(r'rucher_(\d+)').firstMatch(b.id);

      if (aMatch != null && bMatch != null) {
        final aNum = int.tryParse(aMatch.group(1)!) ?? 0;
        final bNum = int.tryParse(bMatch.group(1)!) ?? 0;
        return aNum.compareTo(bNum);
      }

      // Fallback to string comparison if regex doesn't match
      return a.id.compareTo(b.id);
    });
    return ruchers;
  }

  void _loadSpecificApiculteurFromSnapshot(DataSnapshot snapshot, String apiculteurId) {
    setState(() {
      _apiculteurs = [];
      _rucherToApiculteurMap.clear();

      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value as Map<dynamic, dynamic>;

        // Extract ruchers for this apiculteur
        final List<RucherInfo> ruchersList = [];
        value.forEach((rKey, rValue) {
          if (rKey.toString().startsWith('rucher') && rValue is Map<dynamic, dynamic>) {
            // Count ruches in this rucher
            int rucheCount = 0;
            rValue.forEach((key, _) {
              if (key.toString().startsWith('ruche')) {
                rucheCount++;
              }
            });

            // Load ruches data for this rucher
            List<RucheInfo> ruches = _loadRuchesForRucher(rValue, rKey.toString(), apiculteurId);

            // Count alerts in this rucher
            int alertCount = _countRucherAlerts(rValue);

            // Add to mapping for later reference
            _rucherToApiculteurMap[rKey.toString()] = apiculteurId;

            ruchersList.add(RucherInfo(
              id: rKey.toString(),
              address: rValue['address'] ?? '',
              description: rValue['desc'] ?? '',
              picUrl: rValue['pic'] ?? '',
              rucheCount: rucheCount,
              ruches: ruches, // Now providing the required parameter
              alertCount: alertCount,
              isExpanded: false,
            ));
          }
        });

        // Sort the ruchers list before adding to apiculteur
        final sortedRuchers = _sortRuchers(ruchersList);

        _apiculteurs.add(ApiculteurWithRuchers(
          id: apiculteurId,
          nom: value['nom'] ?? '',
          prenom: value['prenom'] ?? '',
          ruchers: sortedRuchers,
        ));
      }
      _isLoading = false;
    });
  }

  void _loadApiculteursFromSnapshot(DataSnapshot snapshot) {
    // If user is an apiculteur, only load their data
    if (_userRole == UserRole.apiculteur && _currentApiculteurId.isNotEmpty) {
      final specificApiculteurRef = _apiculteursRef.child(_currentApiculteurId);
      specificApiculteurRef.get().then((apiculteurSnapshot) {
        if (apiculteurSnapshot.exists && apiculteurSnapshot.value != null) {
          _loadSpecificApiculteurFromSnapshot(apiculteurSnapshot, _currentApiculteurId);
        }
      });
      return;
    }

    // For admin role, load all apiculteurs
    setState(() {
      _apiculteurs = [];
      _rucherToApiculteurMap.clear();

      if (snapshot.exists && snapshot.value != null) {
        final map = snapshot.value as Map<dynamic, dynamic>;
        map.forEach((key, value) {
          if (key.toString().startsWith('api')) {
            // Extract ruchers for this apiculteur
            final List<RucherInfo> ruchersList = [];
            if (value is Map<dynamic, dynamic>) {
              value.forEach((rKey, rValue) {
                if (rKey.toString().startsWith('rucher') && rValue is Map<dynamic, dynamic>) {
                  // Count ruches in this rucher
                  int rucheCount = 0;
                  rValue.forEach((key, _) {
                    if (key.toString().startsWith('ruche')) {
                      rucheCount++;
                    }
                  });

                  // Load ruches data for this rucher
                  List<RucheInfo> ruches = _loadRuchesForRucher(rValue, rKey.toString(), key.toString());

                  // Count alerts in this rucher
                  int alertCount = _countRucherAlerts(rValue);

                  // Add to mapping for later reference
                  _rucherToApiculteurMap[rKey.toString()] = key.toString();

                  ruchersList.add(RucherInfo(
                    id: rKey.toString(),
                    address: rValue['address'] ?? '',
                    description: rValue['desc'] ?? '',
                    picUrl: rValue['pic'] ?? '',
                    rucheCount: rucheCount,
                    ruches: ruches, // Now providing the required parameter
                    alertCount: alertCount,
                    isExpanded: false,
                  ));
                }
              });
            }

            // Sort the ruchers list before adding to apiculteur
            final sortedRuchers = _sortRuchers(ruchersList);

            _apiculteurs.add(ApiculteurWithRuchers(
              id: key.toString(),
              nom: value['nom'] ?? '',
              prenom: value['prenom'] ?? '',
              ruchers: sortedRuchers,
            ));
          }
        });
      }
      _isLoading = false;
    });
  }

  // Add a new rucher to an apiculteur
  Future<void> _addRucher(ApiculteurWithRuchers apiculteur) async {
    // Show dialog to collect rucher information
    final TextEditingController addressController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController picController = TextEditingController();

    // Generate a new rucher ID with proper formatting (rucher_001, rucher_002, etc.)
    int nextRucherNumber = apiculteur.ruchers.length + 1;
    String newRucherId = 'rucher_${nextRucherNumber.toString().padLeft(3, '0')}';

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Rucher'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: picController,
                  decoration: const InputDecoration(labelText: 'Picture URL'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        // Add the new rucher to Firebase under the apiculteur
        await _apiculteursRef.child('${apiculteur.id}/$newRucherId').set({
          'address': addressController.text,
          'desc': descController.text,
          'pic': picController.text,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rucher added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding rucher: ${e.toString()}')),
        );
      }
    }
  }

  // Edit a rucher field
  Future<void> _editRucher(RucherInfo rucher) async {
    final String? apiculteurId = _rucherToApiculteurMap[rucher.id];
    if (apiculteurId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Cannot determine apiculteur for this rucher')),
      );
      return;
    }

    // Controllers for editing fields
    final TextEditingController addressController = TextEditingController(text: rucher.address);
    final TextEditingController descController = TextEditingController(text: rucher.description);
    final TextEditingController picController = TextEditingController(text: rucher.picUrl);

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit ${rucher.id}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: picController,
                  decoration: const InputDecoration(labelText: 'Picture URL'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        // Update the rucher in Firebase
        await _apiculteursRef.child('$apiculteurId/${rucher.id}').update({
          'address': addressController.text,
          'desc': descController.text,
          'pic': picController.text,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rucher updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating rucher: ${e.toString()}')),
        );
      }
    }
  }

  // Delete a rucher
  Future<void> _deleteRucher(RucherInfo rucher) async {
    final String? apiculteurId = _rucherToApiculteurMap[rucher.id];
    if (apiculteurId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Cannot determine apiculteur for this rucher')),
      );
      return;
    }

    // Confirm deletion
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Rucher'),
          content: Text('Are you sure you want to delete ${rucher.id}? This will also delete all ruches inside it.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        // Delete the rucher from Firebase
        await _apiculteursRef.child('$apiculteurId/${rucher.id}').remove();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${rucher.id} deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting rucher: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If user role is unknown, show an error message
    if (_userRole == UserRole.unknown) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Accès Refusé'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Accès non autorisé',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vous n\'avez pas les droits nécessaires pour accéder à cette vue.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
      return Scaffold(
        appBar: AppBar(
          title: Text(_userRole == UserRole.admin ? 'Listes des Ruchers (Admin)' : 'Mes Ruchers'),
          actions: [
            // Add refresh button in the AppBar
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                if (_userRole == UserRole.admin) {
                  _loadApiculteurs();
                } else {
                  _loadCurrentApiculteur(FirebaseAuth.instance.currentUser?.email ?? '');
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Liste des ruchers actualisés... '), duration: Duration(seconds: 1)),
                );
              },
              tooltip: 'Refresh Data',
            ),
          ],
        ),
        body: Column(
          children: [
            // IMPROVED ALERT BANNER - More prominent and better styling
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _getTotalActiveAlerts() > 0 ? 80 : 0,
              child: _getTotalActiveAlerts() > 0
                  ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade100, Colors.red.shade50],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade200.withOpacity(0.5),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.warning_amber, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '⚠️ ${_getTotalActiveAlerts()} ruche(s) en alerte - Vol de miel détecté!',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Icon(Icons.error, color: Colors.red.shade700, size: 28),
                  ],
                ),
              )
                  : const SizedBox.shrink(),
            ),
            // List of apiculteurs and ruchers
            Expanded(
              child: ListView.builder(
                itemCount: _apiculteurs.length,
                itemBuilder: (context, index) {
                  final apiculteur = _apiculteurs[index];

                  // Calculate total alerts for this apiculteur
                  //int apiculteurAlerts = apiculteur.ruchers.fold(0, (sum, rucher) => sum + rucher.alertCount);
                  int apiculteurAlerts = _getTotalActiveAlerts();
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    elevation: apiculteurAlerts > 0 ? 4 : 2,
                    color: apiculteurAlerts > 0 ? Colors.red.shade50 : null,
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Text('${apiculteur.prenom} ${apiculteur.nom}'),
                          if (apiculteurAlerts > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '⚠️ $apiculteurAlerts',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      leading: Icon(
                        Icons.person,
                        color: apiculteurAlerts > 0 ? Colors.red : null,
                      ),
                      subtitle: Text(
                        '${apiculteur.ruchers.length} ruchers' +
                            (apiculteurAlerts > 0 ? ' - $apiculteurAlerts alerte(s)' : ''),
                        style: TextStyle(
                          color: apiculteurAlerts > 0 ? Colors.red.shade700 : null,
                          fontWeight: apiculteurAlerts > 0 ? FontWeight.w600 : null,
                        ),
                      ),
                      trailing: _userRole == UserRole.admin ||
                          (apiculteur.id == _currentApiculteurId && _userRole == UserRole.apiculteur)
                          ? IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addRucher(apiculteur),
                        tooltip: 'Add Rucher',
                      )
                          : null,
                      initiallyExpanded: apiculteur.isExpanded || apiculteurAlerts > 0, // Auto-expand if alerts
                      onExpansionChanged: (expanded) {
                        setState(() {
                          apiculteur.isExpanded = expanded;
                        });
                      },
                      children: apiculteur.ruchers.map((rucher) {
                        return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            elevation: rucher.alertCount > 0 ? 3 : 1,
                            color: rucher.alertCount > 0 ? Colors.red.shade50 : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                              ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image(
                                image: AssetImage('assets/${rucher.picUrl}'),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(
                                children: [
                                Text(
                                rucher.id,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: apiculteurAlerts > 0 ? Colors.red.shade800 : null,
                                  ),
                                ),
                                // Enhanced alert indicator
                                if (rucher.alertCount > 0) ...[
                            const SizedBox(width: 8),
                        Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                        BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 2,
                        ),
                        ],
                        ),
                        ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('📍 ${rucher.address}'),
                                      Text('📝 ${rucher.description}'),
                                      Text('🐝 Ruches: ${rucher.rucheCount}'),
                                      // Show alert text if there are alerts
                                      if (rucher.alertCount > 0)
                                        Text(
                                          '🚨 ${rucher.alertCount} alerte(s) active(s)',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Only show edit/delete buttons for admin or the owner apiculteur
                                if (_userRole == UserRole.admin ||
                                    (apiculteur.id == _currentApiculteurId && _userRole == UserRole.apiculteur))
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editRucher(rucher),
                                        tooltip: 'Edit Rucher',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _deleteRucher(rucher),
                                        tooltip: 'Delete Rucher',
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
  }

  // You can replace the existing RucherListContent with this new implementation
  class RucherListContent extends StatelessWidget {
    const RucherListContent({Key? key}) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return const RucherApiculteurView();
    }
  }