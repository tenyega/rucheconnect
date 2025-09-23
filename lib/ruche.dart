import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tp_flutter/ruche_detailpage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_email_js/flutter_email_js.dart';

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

// User role enum
enum UserRole {
  admin,
  apiculteur,
  unknown
}

class AlertRecord {
  final DateTime sentAt;
  final String dataPointKey;
  final String alertKey;

  AlertRecord({
    required this.sentAt,
    required this.dataPointKey,
    required this.alertKey,
  });
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
  Map<String, AlertRecord> _alertsSent = {};

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }
  String extractBase64Data(String base64String) {
    // Remove the data URL prefix (data:image/jpeg;base64,)
    if (base64String.contains(',')) {
      return base64String.split(',')[1];
    }
    return base64String;
  }
  Widget buildBase64Image(String base64String, {double? width, double? height}) {
    try {
      // Extract pure base64 data
      String cleanBase64 = extractBase64Data(base64String);

      // Decode base64 to bytes
      Uint8List bytes = base64Decode(cleanBase64);

      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey.shade50,
            child: Icon(Icons.error, color: Colors.red),
          );
        },
      );
    } catch (e) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade50,
        child: Icon(Icons.image_not_supported, color: Colors.grey.shade700),
      );
    }
  }

  bool _shouldSendAlert({
    required String apiculteurId,
    required String rucherId,
    required String rucheId,
    required String dataPointKey,
  }) {
    final alertKey = '${apiculteurId}_${rucherId}_${rucheId}';
    final now = DateTime.now();

    // Check if we have a record for this ruche
    if (_alertsSent.containsKey(alertKey)) {
      final lastAlert = _alertsSent[alertKey]!;

      // If it's the same data point, don't send again
      if (lastAlert.dataPointKey == dataPointKey) {
        print('🚫 Skipping alert - same data point already sent: $dataPointKey');
        return false;
      }

      // If less than 30 minutes have passed, don't send again
      final timeDifference = now.difference(lastAlert.sentAt);
      if (timeDifference.inMinutes < 30) {
        print('🚫 Skipping alert - cooldown period active (${timeDifference.inMinutes} minutes ago)');
        return false;
      }
    }

    print('✅ Alert should be sent for $alertKey with data point $dataPointKey');
    return true;
  }

  void _recordAlertSent({
    required String apiculteurId,
    required String rucherId,
    required String rucheId,
    required String dataPointKey,
  }) {
    final alertKey = '${apiculteurId}_${rucherId}_${rucheId}';
    _alertsSent[alertKey] = AlertRecord(
      sentAt: DateTime.now(),
      dataPointKey: dataPointKey,
      alertKey: alertKey,
    );
    print('📝 Alert recorded: $alertKey -> $dataPointKey at ${DateTime.now()}');
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
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && currentUser.email != null) {
      final String email = currentUser.email!;

      // Check if the user is an admin (email is test@gmail.com)
      if (email == 'test@gmail.com') {
        setState(() {
          _userRole = UserRole.admin;
          _isLoading = false;
        });
      } else {
        // Check if the email exists in the apiculteurs database
        try {
          final DatabaseReference apiculteursRef = FirebaseDatabase.instance.ref('apiculteurs');
          final snapshot = await apiculteursRef.get();

          bool isApiculteur = false;

          if (snapshot.exists && snapshot.value != null) {
            final Map<dynamic, dynamic> apiculteurs = snapshot.value as Map<dynamic, dynamic>;

            // Check if any apiculteur has this email
            for (var apiculteurData in apiculteurs.values) {
              if (apiculteurData is Map && apiculteurData['email'] == email) {
                isApiculteur = true;
                break;
              }
            }
          }

          if (isApiculteur) {
            setState(() {
              _userRole = UserRole.apiculteur;
              _isLoading = false;
            });
          } else {
            // Email not found in apiculteurs - set to unknown role
            setState(() {
              _userRole = UserRole.unknown;
              _isLoading = false;
            });
          }
        } catch (e) {
          // Error accessing database - set to unknown role
          setState(() {
            _userRole = UserRole.unknown;
            _isLoading = false;
          });
        }
      }
    } else {
      // No current user - set to unknown role
      setState(() {
        _userRole = UserRole.unknown;
        _isLoading = false;
      });
    }
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
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendAlertEmailAsync({
    required String recipientEmail,
    required String apiculteurName,
    required String rucheId,
    required String rucherId,
    required RucheDataPoint latestDataPoint,
  }) {
    // Static flag to prevent overlapping sends - make it instance variable instead
    bool _isCurrentlySending = false;

    _isCurrentlySending = true;

    // Send email asynchronously
    Future.microtask(() async {
      try {
        print('🚨 Starting email send process...');
        print('   To: $recipientEmail');
        print('   Ruche: $rucheId');
        print('   Temperature: ${latestDataPoint.temperature}°C');
        print('   Humidity: ${latestDataPoint.humidity}%');
        print('   Couvercle: ${latestDataPoint.couvercle == 1 ? "Open" : "Closed"}');

        // ✅ IMPROVED: Send actual alert email with proper data
        await _sendAlertEmail(
          recipientEmail: recipientEmail,
          rucheId: rucheId,
          rucherId: rucherId,
          temperature: latestDataPoint.temperature.toString(),
          humidity: latestDataPoint.humidity.toString(),
          weight: 'N/A', // You might want to add weight to RucheDataPoint
        );

        print('✅ Alert email sent successfully');

        // Add delay to prevent rapid sending
        await Future.delayed(Duration(seconds: 5));

      } catch (e) {
        print('❌ Failed to send alert email: $e');
      } finally {
        _isCurrentlySending = false;
      }
    });
  }

  Future<void> _loadCurrentApiculteur(String userEmail) async {
    try {
      // Store the current user email for filtering
      _currentUserEmail = userEmail;

      final snapshot = await _apiculteursRef.get();
      _loadApiculteursFromSnapshot(snapshot);

      // Set up the listener for real-time updates
      _apiculteursRef.onValue.listen((event) {
        _loadApiculteursFromSnapshot(event.snapshot);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _loadApiculteursFromSnapshot(DataSnapshot snapshot) {
    setState(() {
      _apiculteurs = [];
      // IMPORTANT: Don't clear _alertsSent here - keep alert history

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

      // Sort apiculteurs...
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

    // Sort ruchers and ruches
    for (var apiculteur in _apiculteurs) {
      apiculteur.ruchers.sort((a, b) {
        final aNum = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bNum = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return aNum.compareTo(bNum);
      });

      for (var rucher in apiculteur.ruchers) {
        rucher.ruches.sort((a, b) {
          final aNum = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final bNum = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return aNum.compareTo(bNum);
        });
      }
    }
  }

  Future<String?> _getApiculteurEmail(String apiculteurId) async {
    try {
      final snapshot = await _apiculteursRef.child(apiculteurId).get();

      if (snapshot.exists && snapshot.value != null) {
        final apiculteurData = snapshot.value as Map<dynamic, dynamic>;
        return apiculteurData['email']?.toString();
      }

      return null;
    } catch (e) {
      print('❌ Error getting apiculteur email: $e');
      return null;
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
      print('Current couvercle status: ${latestDataPoint.couvercle == 1 ? "Open" : "Closed"}');

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

            // ✅ NEW: Send alert email ONLY when activating alerts AND lid is open
            if (newAlertStatus && latestDataPoint.couvercle == 1) {
              print('🚨 Alert activated AND lid is open - sending alert email');

              // Get apiculteur info for email
              final apiculteur = _apiculteurs.firstWhere(
                    (api) => api.id == apiculteurId,
                orElse: () => throw Exception('Apiculteur not found'),
              );

              final updatedDataPoint = RucheDataPoint.fromString(updatedValue);

              _sendAlertEmailAsync(
                recipientEmail: apiculteur.email,
                apiculteurName: '${apiculteur.prenom} ${apiculteur.nom}',
                rucheId: ruche.id,
                rucherId: rucherId,
                latestDataPoint: updatedDataPoint,
              );

              _recordAlertSent(
                apiculteurId: apiculteurId,
                rucherId: rucherId,
                rucheId: ruche.id,
                dataPointKey: latestKey,
              );
            } else if (newAlertStatus) {
              print('ℹ️ Alert activated but lid is closed - no email sent');
            } else {
              print('ℹ️ Alert deactivated - no email sent');
            }
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
          backgroundColor: newAlertStatus ? Colors.green : Colors.grey.shade700,
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

  // Replace your sendEmail method with this corrected version:
  Future<void> sendEmail({
    required String rucherId,
    required String rucheId,
    required String email,
  }) async {
    const serviceId = 'service_8yivchs';
    const templateId = 'template_dn9kieg';
    const userId = 'FTgZiqrq5bPlnYvU4'; // your EmailJS public key

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost', // or 'http://yourdomain.com' (for web), optional on mobile
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': userId,
        'template_params': {
          'rucher_id': rucherId,
          'ruche_id': rucheId,
          'email': email,
        }
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Email sent successfully!');
    } else {
      print('❌ Failed to send email. Status: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
    }
  }

  // Updated method to replace in your existing code
  Future<void> _sendAlertEmail({
    required String recipientEmail,
    required String rucheId,
    required String rucherId,
    required String temperature,
    required String humidity,
    required String weight,
  }) async {
    try {
      print('🚨 _sendAlertEmail called with:');
      print('   Email: $recipientEmail');
      print('   Ruche: $rucheId');
      print('   Rucher: $rucherId');

      // Validate email address
      if (recipientEmail.isEmpty || !recipientEmail.contains('@')) {
        throw Exception('Invalid email address: $recipientEmail');
      }

      final now = DateTime.now();
      final formattedDate = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} à ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      // Clean temperature data
      String cleanTemperature = temperature.replaceAll(RegExp(r'[^0-9.-]'), '');
      if (cleanTemperature.isEmpty) cleanTemperature = 'N/A';

      final alertMessage = '''🚨 ALERTE RUCHE - Couvercle Ouvert

Attention! Le couvercle de votre ruche est ouvert.

Détails de la Ruche:
• ID Ruche: $rucheId
• ID Rucher: $rucherId  
• Date/Heure: $formattedDate

Données Actuelles:
• 🌡️ Température: ${cleanTemperature}°C
• 💧 Humidité: ${humidity}%
• ⚖️ Poids: ${weight}kg
• 🔓 Couvercle: OUVERT

Action recommandée:
Veuillez vérifier votre ruche dès que possible.''';

      await sendEmail(rucherId: '$rucheId', rucheId: '$rucheId', email: '$recipientEmail');
      print('✅ Email sent successfully to $recipientEmail');
    } catch (e) {
      print('❌ Error in _sendAlertEmail: $e');
      rethrow;
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
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
            SnackBar(
              content: Text('Ruche deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting ruche: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
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
            backgroundColor: Colors.white,
            title: Text(
              'Add New Ruche',
              style: TextStyle(
                color: Colors.amber.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.amber.shade800),
                hintText: 'Enter ruche description...',
                hintStyle: TextStyle(color: Colors.grey.shade700),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.amber),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.amber.shade800, width: 2),
                ),
              ),
              maxLines: 3,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: Text('Add'),
              ),
            ],
          );
        },
      );

      if (result == true) {
        final apiculteurId = rucher.ruches.isNotEmpty ? rucher.ruches.first.apiculteurId : null;

        if (apiculteurId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Cannot determine apiculteur for this rucher'),
              backgroundColor: Colors.red,
            ),
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
            SnackBar(
              content: Text('Ruche added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding ruche: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    Widget _buildRucherImage(String imageData) {
      try {
        // Check if it's a Base64 string (typically starts with data: or just the base64 part)
        if (imageData.startsWith('data:image/') || _isBase64String(imageData)) {
          return buildBase64Image(imageData, height: 200);
        } else {
          // It's a filename/URL - handle accordingly
          if (imageData.startsWith('img') || imageData.startsWith('img')) {
            // It's a URL

            return Image.asset('assets/$imageData',
              height: 50,
              width: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade50,
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey.shade700),
                );
              },
            );
          } else {
            // It's a local asset or file
            return Image.asset(
              imageData,
              height: 50,
              width: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade50,
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey.shade700),
                );
              },
            );
          }
        }
      } catch (e) {
        // Fallback for any errors
        return Container(
          color: Colors.grey.shade50,
          child: Icon(Icons.broken_image, size: 50, color: Colors.grey.shade700),
        );
      }
    }

    bool _isBase64String(String str) {
      try {
        // Basic check for Base64 pattern
        RegExp base64RegExp = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
        return base64RegExp.hasMatch(str) && str.length % 4 == 0;
      } catch (e) {
        return false;
      }
    }

    bool _canUserModify(ApiculteurWithRuchers apiculteur) {
      return _userRole == UserRole.admin ||
          (_userRole == UserRole.apiculteur && apiculteur.email == _currentUserEmail);
    }

    @override
    Widget build(BuildContext context) {
      if (_userRole == UserRole.unknown && !_isLoading) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Text(
              'Accès non autorisé',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
              ),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            _userRole == UserRole.admin ? 'Liste des ruches (Admin)' : 'Mes ruches',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.black),
              tooltip: 'Rafraîchir',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.amber.shade100,
                    content: Text(
                      'Liste des ruches actualisée...',
                      style: TextStyle(
                        color: Colors.black, // ✅ Text color set manually here
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
                if (!mounted) return;
                setState(() {
                  _isLoading = true;
                });
                // Conditional loading based on user role
                if (_userRole == UserRole.admin) {
                  _loadApiculteurs(); // Load all apiculteurs for admin
                } else {
                  _loadCurrentApiculteur(FirebaseAuth.instance.currentUser?.email ?? ''); // Load only current user's data
                }
              },
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.amber.shade100,
                Colors.amber.shade50,
              ],
            ),
          ),
          child: _isLoading
              ? Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.amber.shade200,
            ),
          )
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
                    border: Border.all(color: Colors.red.shade200, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red, size: 10),
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
                      color: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          '${apiculteur.prenom} ${apiculteur.nom}',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          '${apiculteur.ruchers.length} ruchers${_userRole == UserRole.admin ? ' • ${apiculteur.email}' : ''}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        iconColor: Colors.amber.shade800,
                        children: [
                          ...apiculteur.ruchers.map((rucher) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 150,
                                          width: 100,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.amber.shade200),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: rucher.picUrl != null && rucher.picUrl!.isNotEmpty
                                                ? _buildRucherImage(rucher.picUrl!)
                                                : Container(
                                              color: Colors.grey.shade50,
                                              child: Icon(Icons.image, size: 50, color: Colors.grey.shade700),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                rucher.id,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.amber.shade800,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '📍 ${rucher.address}',
                                                style: TextStyle(color: Colors.grey.shade700),
                                              ),
                                              Text(
                                                '📝 ${rucher.description}',
                                                style: TextStyle(color: Colors.grey.shade700),
                                              ),
                                              Text(
                                                '🐝 Ruches: ${rucher.ruches.length}',
                                                style: TextStyle(color: Colors.grey.shade700),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Add Ruche button with + sign - Only show if user can modify
                                    if (canModify)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _addRuche(rucher),
                                                icon: Icon(Icons.add, color: Colors.black),
                                                label: Text('Add Ruche', style: TextStyle(color: Colors.black)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.amber,
                                                  foregroundColor: Colors.black,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ...rucher.ruches.map((ruche) {
                                      final latestData = getLatestDataPoint(ruche);
                                      final hasAlert = _hasActiveAlert(ruche);
                                      return Card(
                                        // More prominent alert coloring
                                        color: hasAlert ? Colors.red.shade100 : Colors.white,
                                        elevation: hasAlert ? 4 : 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Container(
                                          decoration: hasAlert
                                              ? BoxDecoration(
                                            border: Border.all(color: Colors.red, width: 2),
                                            borderRadius: BorderRadius.circular(8),
                                          )
                                              : null,
                                          child: ListTile(
                                            // Enhanced leading icon with animation potential
                                            leading: Stack(
                                              children: [
                                                Icon(
                                                  hasAlert ? Icons.warning : Icons.hive,
                                                  color: hasAlert ? Colors.red : Colors.amber.shade800,
                                                  size: 30,
                                                ),
                                                if (hasAlert)
                                                  Positioned(
                                                    right: 0,
                                                    top: 0,
                                                    child: Container(
                                                      width: 10,
                                                      height: 10,
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
                                                      color: hasAlert ? Colors.red.shade800 : Colors.amber.shade800,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '📊 Données: ${ruche.dataPoints.length}',
                                                  style: TextStyle(color: Colors.grey.shade700),
                                                ),
                                                if (latestData != null) ...[
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          '🌡️ ${latestData.temperature}°C',
                                                          style: TextStyle(
                                                            fontSize: 12, // or whatever your base size is
                                                            color: Colors.grey.shade700,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Flexible(
                                                        child: Text(
                                                          '💧 ${latestData.humidity}%',
                                                          style: TextStyle(color: Colors.grey.shade700),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'Couvercle:',
                                                        style: TextStyle(
                                                          color: Colors.grey.shade700,
                                                          fontSize: 10, // ✅ now it's correctly placed
                                                        ),
                                                      ),

                                                      Flexible(
                                                        child: Text(
                                                          latestData.couvercle == 1 ? "Ouvert" : "Fermé",
                                                          style: TextStyle(
                                                            color: latestData.couvercle == 1 ? Colors.red : Colors.green,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (hasAlert)
                                                    Container(
                                                      margin: const EdgeInsets.only(top: 4),
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.shade50,
                                                        borderRadius: BorderRadius.circular(2),
                                                        border: Border.all(color: Colors.red.shade200),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.error, color: Colors.red, size: 12),
                                                          const SizedBox(width: 4),
                                                          Flexible( // ✅ prevent overflow
                                                            child: Text(
                                                              'Vol détecté!',
                                                              style: TextStyle(
                                                                color: Colors.red.shade800,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.normal,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                              softWrap: false,
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
                                                      size: 10,
                                                      color: hasAlert ? Colors.red : Colors.green,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Flexible(
                                                      child: Text(
                                                        'Voir détails',
                                                        style: TextStyle(
                                                          color: hasAlert ? Colors.red : Colors.green,
                                                          fontSize: 10,
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
                                                          ? Icons.notifications // Bell (alert enabled)
                                                          : Icons.notifications_off, // Bell with slash (alert disabled)
                                                      color: ruche.alertActive ? Colors.red : Colors.green,
                                                      size: 24,
                                                    ),
                                                    onPressed: () => _toggleAlertStatus(ruche),
                                                    tooltip: ruche.alertActive
                                                        ? 'Désactiver les alertes'
                                                        : 'Activer les alertes',
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.delete, color: Colors.red),
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
        ),
      );
    }
}
