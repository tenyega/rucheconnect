
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:tp_flutter/ruche_detailpage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

// Model class for apiculteur with rucher and ruche info
class ApiculteurWithRuchers {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final List<RucherWithRuches> ruchers;
  bool isExpanded;

  ApiculteurWithRuchers({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.ruchers,
    this.isExpanded = false,
  });
}

// Model class for rucher with ruches
class RucherWithRuches {
  final String id;
  final String address;
  final String description;
  final String picUrl;
  final List<RucheInfo> ruches;
  bool isExpanded;

  RucherWithRuches({
    required this.id,
    required this.address,
    required this.description,
    required this.picUrl,
    required this.ruches,
    this.isExpanded = false,
  });
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

// Email service for sending alerts
class EmailService {
  static Future<bool> sendAlertEmail({
    required String recipientEmail,
    required String apiculteurName,
    required String rucheId,
    required String rucherId,
  }) async {
    try {
      // Replace with your email service endpoint
      const String emailServiceUrl = 'YOUR_EMAIL_SERVICE_ENDPOINT';

      final response = await http.post(
        Uri.parse(emailServiceUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'to': recipientEmail,
          'subject': '🚨 ALERTE RUCHE - Vol de miel détecté',
          'html': '''
            <h2>Alerte de Sécurité - Ruche ${rucheId}</h2>
            <p>Bonjour ${apiculteurName},</p>
            <p><strong>Une activité suspecte a été détectée sur votre ruche!</strong></p>
            <ul>
              <li>Rucher: ${rucherId}</li>
              <li>Ruche: ${rucheId}</li>
              <li>Détection: Couvercle ouvert de manière suspecte</li>
              <li>Heure: ${DateTime.now().toString()}</li>
            </ul>
            <p>⚠️ Il est possible que quelqu'un soit en train de voler le miel de votre ruche.</p>
            <p>Nous vous recommandons de vérifier votre ruche dès que possible.</p>
            <p>Cordialement,<br>Système de Surveillance des Ruches</p>
          ''',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }
}

// User role enum
enum UserRole {
  admin,
  apiculteur,
  unknown
}

// Main widget for the rucher & ruche view
class RucherRucheViewState extends StatefulWidget {
  const RucherRucheViewState({Key? key}) : super(key: key);

  @override
  State<RucherRucheViewState> createState() => _RucherRucheViewState();
}

class _RucherRucheViewState extends State<RucherRucheViewState> {
  final DatabaseReference _apiculteursRef = FirebaseDatabase.instance.ref('apiculteurs');
  List<ApiculteurWithRuchers> _apiculteurs = [];
  bool _isLoading = true;
  UserRole _userRole = UserRole.unknown;
  String? _currentUserEmail;
  Set<String> _alertsSent = {}; // Track which alerts have been sent

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  int _getTotalActiveAlerts() {
    int totalAlerts = 0;
    for (var apiculteur in _apiculteurs) {
      apiculteur.ruchers.sort((a, b) => a.id.compareTo(b.id));
      for (var rucher in apiculteur.ruchers) {
        rucher.ruches.sort((a, b) => a.id.compareTo(b.id));
        for (var ruche in rucher.ruches) {
          if (_hasActiveAlert(ruche)) {
            totalAlerts++;
          }
        }
      }
    }
    return totalAlerts;
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.email != null) {
      final email = user.email!;
      _currentUserEmail = email;

      if (email == 'test@gmail.com') {
        _userRole = UserRole.admin;
      } else if (email.endsWith('@email.com')) {
        _userRole = UserRole.apiculteur;
      } else {
        _userRole = UserRole.unknown;
      }
    }

    await _loadApiculteurs();
  }

  Future<void> _loadApiculteurs() async {
    try {
      final snapshot = await _apiculteursRef.get();
      _loadApiculteursFromSnapshot(snapshot);

      _apiculteursRef.onValue.listen((event) {
        _loadApiculteursFromSnapshot(event.snapshot);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
    }
  }

  void _loadApiculteursFromSnapshot(DataSnapshot snapshot) {
    setState(() {
      _apiculteurs = [];
      _alertsSent.clear();

      if (snapshot.exists && snapshot.value != null) {
        final map = snapshot.value as Map<dynamic, dynamic>;
        map.forEach((apiKey, apiValue) {
          if (apiKey.toString().startsWith('api') && apiValue is Map<dynamic, dynamic>) {
            final apiculteurEmail = apiValue['email']?.toString() ?? '';
            final apiculteurNom = apiValue['nom']?.toString() ?? '';
            final apiculteurPrenom = apiValue['prenom']?.toString() ?? '';

            if (_userRole == UserRole.apiculteur && apiculteurEmail != _currentUserEmail) {
              return;
            }

            final List<RucherWithRuches> ruchersList = [];

            apiValue.forEach((rucherKey, rucherValue) {
              if (rucherKey.toString().startsWith('rucher') && rucherValue is Map<dynamic, dynamic>) {
                final List<RucheInfo> ruchesList = [];

                rucherValue.forEach((rucheKey, rucheValue) {
                  if (rucheKey.toString().startsWith('ruche') && rucheValue is Map<dynamic, dynamic>) {
                    final Map<String, RucheDataPoint> dataPoints = {};

                    RucheDataPoint? latestDataPoint;
                    String? latestKey;
                    int latestTimestamp = 0;

                    rucheValue.forEach((dpKey, dpValue) {
                      if (dpValue is String && dpKey != 'desc') {
                        try {
                          final dataPoint = RucheDataPoint.fromString(dpValue);
                          dataPoints[dpKey.toString()] = dataPoint;

                          final keyAsInt = int.tryParse(dpKey.toString()) ?? 0;
                          if (keyAsInt > latestTimestamp) {
                            latestTimestamp = keyAsInt;
                            latestDataPoint = dataPoint;
                            latestKey = dpKey.toString();
                          }
                        } catch (_) {}
                      }
                    });

                    // Send alert email logic
                    if (latestDataPoint != null) {
                      bool checkAlertCondition(RucheDataPoint? latestDataPoint) {
                        if (latestDataPoint == null) return false;

                        final alert = latestDataPoint.alert ?? 0;
                        final couvercle = latestDataPoint.couvercle ?? 0;

                        return (alert == 1 && couvercle == 1);
                      }

                      if (checkAlertCondition(latestDataPoint)) {
                        final alertKey = '${apiKey}_${rucherKey}_${rucheKey}_$latestKey';
                        if (!_alertsSent.contains(alertKey)) {
                          _sendAlertEmail(
                            apiculteurEmail,
                            '$apiculteurPrenom $apiculteurNom',
                            rucheKey.toString(),
                            rucherKey.toString(),
                          );
                          _alertsSent.add(alertKey);
                        }
                      }
                    }

                    ruchesList.add(RucheInfo(
                      id: rucheKey.toString(),
                      rucherId: rucherKey.toString(),
                      apiculteurId: apiKey.toString(),
                      dataPoints: dataPoints,
                    ));
                  }
                });

                ruchersList.add(RucherWithRuches(
                  id: rucherKey.toString(),
                  address: rucherValue['address']?.toString() ?? '',
                  description: rucherValue['desc']?.toString() ?? '',
                  picUrl: rucherValue['pic']?.toString() ?? '',
                  ruches: ruchesList,
                ));
              }
            });

            _apiculteurs.add(ApiculteurWithRuchers(
              id: apiKey.toString(),
              nom: apiculteurNom,
              prenom: apiculteurPrenom,
              email: apiculteurEmail,
              ruchers: ruchersList,
            ));
          }
        });
      }
      // ✅ Sort apiculteurs by ID AFTER all are added
      _apiculteurs.sort((a, b) {
        final aMatch = RegExp(r'api_0*(\d+)').firstMatch(a.id);
        final bMatch = RegExp(r'api_0*(\d+)').firstMatch(b.id);

        if (aMatch != null && bMatch != null) {
          final aNum = int.parse(aMatch.group(1)!);
          final bNum = int.parse(bMatch.group(1)!);
          return aNum.compareTo(bNum);
        }

        return a.id.compareTo(b.id);
      });
      _isLoading = false;
    });
    for (var apiculteur in _apiculteurs) {
      // Sort ruchers by ID (rucher_001, rucher_002, etc.)
      apiculteur.ruchers.sort((a, b) {
        // Extract numeric part from rucher ID for proper sorting
        final aNum = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bNum = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return aNum.compareTo(bNum);
      });

      // Sort ruches within each rucher
      for (var rucher in apiculteur.ruchers) {
        rucher.ruches.sort((a, b) {
          // Extract numeric part from ruche ID for proper sorting
          final aNum = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final bNum = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return aNum.compareTo(bNum);
        });
      }
    }
  }

  Future<void> _sendAlertEmail(String email, String name, String rucheId, String rucherId) async {
    try {
      final success = await EmailService.sendAlertEmail(
        recipientEmail: email,
        apiculteurName: name,
        rucheId: rucheId,
        rucherId: rucherId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alert sent to $email for ruche $rucheId'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error sending alert email: $e');
    }
  }

  Future<void> _toggleAlertStatus(RucheInfo ruche) async {
    final apiculteurId = ruche.apiculteurId;
    final rucherId = ruche.rucherId;

    try {
      // Get current alert status from the latest data point
      final latestDataPoint = ruche.getLatestDataPoint();
      if (latestDataPoint == null) {
        throw Exception('No data points available for this ruche');
      }

      final currentAlertStatus = latestDataPoint.alert == 1;
      final newAlertStatus = !currentAlertStatus;

      print('=== TOGGLE ALERT DEBUG START ===');
      print('ApiculteurId: $apiculteurId');
      print('RucherId: $rucherId');
      print('RucheId: ${ruche.id}');
      print('Current alert status: $currentAlertStatus');
      print('New alert status: $newAlertStatus');

      // Get the key for the latest data point
      final latestKey = ruche.getLatestDataPointKey();
      if (latestKey == null) {
        throw Exception('Could not find latest data point key');
      }

      print('Using key: $latestKey for timestamp: ${latestDataPoint.timestamp}');

      final dataPointPath = '$apiculteurId/$rucherId/${ruche.id}/$latestKey';
      final snapshot = await _apiculteursRef.child(dataPointPath).get();

      if (snapshot.exists && snapshot.value is String) {
        final parts = (snapshot.value as String).split('/');

        if (parts.length >= 5) {
          // Toggle the alert value
          final alertValue = newAlertStatus ? '1' : '0';
          final updatedValue = '${parts[0]}/${parts[1]}/${parts[2]}/${parts[3]}/$alertValue';

          await _apiculteursRef.child(dataPointPath).set(updatedValue);

          // Verify the update
          final verifySnapshot = await _apiculteursRef.child(dataPointPath).get();

          if (verifySnapshot.value == updatedValue) {
            if (!mounted) return;
            setState(() {
              // Update the local dataPoint
              ruche.dataPoints[latestKey] = RucheDataPoint.fromString(updatedValue);
            });
            print('✅ Alert ${newAlertStatus ? "activated" : "deactivated"} for ${ruche.id}');
          } else {
            throw Exception('Failed to verify database update');
          }
        } else {
          throw Exception('Invalid data format - not enough parts');
        }
      } else {
        throw Exception('No data found for the latest dataPoint');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newAlertStatus
              ? 'Alertes activées pour ${ruche.id}'
              : 'Alertes désactivées pour ${ruche.id}'),
          backgroundColor: newAlertStatus ? Colors.green : Colors.grey,
        ),
      );

      print('=== TOGGLE ALERT DEBUG END ===');
    } catch (e, st) {
      print('❌ Error in _toggleAlertStatus: $e');
      print(st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement d\'alerte pour ${ruche.id}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _hasActiveAlert(RucheInfo ruche) {
    // Use the new hasActiveAlert getter from RucheInfo
    return ruche.hasActiveAlert;
  }

  // Helper method to get latest data point for a ruche
  RucheDataPoint? getLatestDataPoint(RucheInfo ruche) {
    return ruche.getLatestDataPoint();
  }

  // Edit a rucher
  Future<void> _editRucher(RucherWithRuches rucher) async {
    final TextEditingController addressController = TextEditingController(text: rucher.address);
    final TextEditingController descController = TextEditingController(text: rucher.description);
    final TextEditingController picController = TextEditingController(text: rucher.picUrl);

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Rucher'),
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
                  decoration: const InputDecoration(labelText: 'Picture filename'),
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
      final apiculteurId = rucher.ruches.isNotEmpty ? rucher.ruches.first.apiculteurId : null;

      if (apiculteurId != null) {
        try {
          final updates = {
            'address': addressController.text.trim(),
            'desc': descController.text.trim(),
            'pic': picController.text.trim(),
          };

          await _apiculteursRef.child('$apiculteurId/${rucher.id}').update(updates);

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
  }

  Future<void> _deleteRucher(RucherWithRuches rucher) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Rucher'),
          content: Text('Are you sure you want to delete rucher ${rucher.id}? This will also delete all ruches in this rucher.'),
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

    if (confirmed == true) {
      final apiculteurId = rucher.ruches.isNotEmpty ? rucher.ruches.first.apiculteurId : null;

      if (apiculteurId != null) {
        try {
          await _apiculteursRef.child('$apiculteurId/${rucher.id}').remove();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rucher deleted successfully')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting rucher: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _deleteRuche(RucheInfo ruche) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Ruche'),
          content: Text('Are you sure you want to delete ruche ${ruche.id}?'),
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

    if (confirmed == true) {
      final rucherId = ruche.rucherId;
      final apiculteurId = ruche.apiculteurId;

      if (apiculteurId != null && rucherId != null) {
        try {
          await _apiculteursRef.child('$apiculteurId/$rucherId/${ruche.id}').remove();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ruche deleted successfully')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting ruche: ${e.toString()}')),
          );
        }
      }
    }
  }

  // Add a new ruche to a rucher
  Future<void> _addRuche(RucherWithRuches rucher) async {
    final TextEditingController descController = TextEditingController();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Ruche'),
          content: TextField(
            controller: descController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Enter ruche description...',
            ),
            maxLines: 3,
            autofocus: true,
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
      final apiculteurId = rucher.ruches.isNotEmpty ? rucher.ruches.first.apiculteurId : null;

      if (apiculteurId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Cannot determine apiculteur for this rucher')),
        );
        return;
      }

      try {
        // Generate new ruche ID
        final existingRucheCount = rucher.ruches.length;
        final newRucheId = 'ruche_00${existingRucheCount + 1}';

        // Create ruche with description and default alert status
        final rucheData = {
          'desc': descController.text.trim()
        };

        await _apiculteursRef.child('$apiculteurId/${rucher.id}/$newRucheId').set(rucheData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ruche added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding ruche: ${e.toString()}')),
        );
      }
    }
  }

  bool _canUserModify(ApiculteurWithRuchers apiculteur) {
    return _userRole == UserRole.admin ||
        (_userRole == UserRole.apiculteur && apiculteur.email == _currentUserEmail);
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == UserRole.unknown && !_isLoading) {
      return const Center(
        child: Text('Accès non autorisé'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Liste des ruches"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Liste des ruches actualisés......')),
              );
              if (!mounted) return;
              setState(() {
                _isLoading = true;
              });
              _loadApiculteurs();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Alert banner
          if (_getTotalActiveAlerts() > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200, width:2),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 24),
                  const SizedBox(width: 12),
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
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _apiculteurs.length,
              itemBuilder: (context, index) {
                final apiculteur = _apiculteurs[index];
                final canModify = _canUserModify(apiculteur);

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ExpansionTile(
                    title: Text('${apiculteur.prenom} ${apiculteur.nom}'),
                    subtitle: Text('${apiculteur.ruchers.length} ruchers • ${apiculteur.email}'),
                    children: [
                      ...apiculteur.ruchers.map((rucher) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.asset(
                                      'assets/${rucher.picUrl}',
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, size: 100),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rucher.id,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('📍 ${rucher.address}'),
                                        Text('📝 ${rucher.description}'),
                                        Text('🐝 Ruches: ${rucher.ruches.length}'),
                                      ],
                                    ),
                                  ),
                                  if (canModify)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
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
                              const SizedBox(height: 8),
                              // Add Ruche button with + sign
                              if (canModify)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _addRuche(rucher),
                                          icon: const Icon(Icons.add, color: Colors.green),
                                          label: const Text('Add Ruche'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.green,
                                            side: const BorderSide(color: Colors.green),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ...rucher.ruches.map((ruche) {
                                final latestData = getLatestDataPoint(ruche);
                                final hasAlert = _hasActiveAlert(ruche);
                                return Card( // Fixed: Changed CardCard to Card
                                  // More prominent alert coloring
                                  color: hasAlert ? Colors.red.shade100 : null,
                                  elevation: hasAlert ? 4 : 1,
                                  child: Container(
                                    decoration: hasAlert ? BoxDecoration(
                                      border: Border.all(color: Colors.red, width: 2),
                                      borderRadius: BorderRadius.circular(4),
                                    ) : null,
                                    child: ListTile(
                                      // Enhanced leading icon with animation potential
                                      leading: Stack(
                                        children: [
                                          Icon(
                                            hasAlert ? Icons.warning : Icons.hive,
                                            color: hasAlert ? Colors.red : Colors.amber,
                                            size: 30,
                                          ),
                                          if (hasAlert)
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 1),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ruche.id,
                                              style: TextStyle(
                                                fontWeight: hasAlert ? FontWeight.bold : FontWeight.normal,
                                                color: hasAlert ? Colors.red.shade800 : null,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),

                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('📊 Données: ${ruche.dataPoints.length}'),
                                          if (latestData != null) ...[
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text('🌡️ ${latestData.temperature}°C'),
                                                ),
                                                const SizedBox(width: 16),
                                                Flexible(
                                                  child: Text('💧 ${latestData.humidity}%'),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Text('Couvercle: '),
                                                Flexible(
                                                  child: Text(
                                                    latestData.couvercle == 1 ? "Ouvert" : "Fermé",
                                                    style: TextStyle(
                                                      color: latestData.couvercle == 1 ? Colors.orange : Colors.green,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (hasAlert)
                                              Container(
                                                margin: const EdgeInsets.only(top: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.red.shade200),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.error, color: Colors.red, size: 2),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Vol de miel détecté!',
                                                      style: TextStyle(
                                                        color: Colors.red.shade800,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )

                                          ],
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.bar_chart,
                                                size: 16,
                                                color: hasAlert ? Colors.red : Colors.green,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'Voir détails',
                                                  style: TextStyle(
                                                    color: hasAlert ? Colors.red : Colors.green,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: canModify
                                          ? SizedBox(
                                        width: 96, // Fixed width to prevent overflow
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                ruche.alertActive
                                                    ? Icons.notifications     // Bell (alert enabled)
                                                    : Icons.notifications_off, // Bell with slash (alert disabled)
                                                color: ruche.alertActive ? Colors.red : Colors.green,
                                                size: 24,
                                              ),
                                              onPressed: () => _toggleAlertStatus(ruche), // ← This calls the function
                                              tooltip: ruche.alertActive
                                                  ? 'Désactiver les alertes'
                                                  : 'Activer les alertes',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              onPressed: () => _deleteRuche(ruche),
                                              tooltip: 'Delete Ruche',
                                            ),
                                          ],
                                        ),
                                      )
                                          : null,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RucheDetailPage(
                                              apiculteurId: apiculteur.id,
                                              rucherId: rucher.id,
                                              rucheId: ruche.id,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
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
