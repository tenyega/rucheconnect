import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';


// Improved utility functions for base64 handling

/// Converts an XFile image to base64 string with proper data URL format
Future<String> convertImageToBase64(XFile imageFile) async {
  try {
    final bytes = await imageFile.readAsBytes();
    final base64String = base64Encode(bytes);

    // Determine MIME type based on file extension
    String mimeType = _getMimeTypeFromFileName(imageFile.name);

    // Return with proper data URL format
    return 'data:$mimeType;base64,$base64String';
  } catch (e) {
    print('Error converting image to base64: $e');
    throw Exception('Failed to convert image to base64: $e');
  }
}

/// Helper function to determine MIME type from file name
String _getMimeTypeFromFileName(String fileName) {
  final extension = fileName.toLowerCase().split('.').last;
  switch (extension) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    default:
      return 'image/jpeg'; // Default fallback
  }
}

/// Improved function to check if a string is valid base64
bool isValidBase64(String str) {
  if (str.isEmpty) return false;

  // Remove data URL prefix if present
  String base64Part = str;
  if (str.startsWith('data:image')) {
    final parts = str.split(',');
    if (parts.length != 2) return false;
    base64Part = parts[1];
  }

  // Check if string contains only valid base64 characters
  final base64RegExp = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
  if (!base64RegExp.hasMatch(base64Part)) return false;

  // Check if length is valid (must be multiple of 4)
  if (base64Part.length % 4 != 0) return false;

  // Try to decode to verify it's valid base64
  try {
    base64Decode(base64Part);
    return true;
  } catch (e) {
    return false;
  }
}

/// FIXED: Enhanced image builder widget with better error handling and loading states
Widget buildImageFromBase64OrPath(
    String imageData, {
      double width = 100,
      double height = 100,
      BoxFit fit = BoxFit.cover,
      BorderRadius? borderRadius,
      Widget? placeholder,
      Widget? errorWidget,
    }) {
  final defaultBorderRadius = borderRadius ?? BorderRadius.circular(8);

  // Default placeholder
  final defaultPlaceholder = placeholder ?? Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: defaultBorderRadius,
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Icon(
      Icons.image,
      size: width * 0.4,
      color: Colors.grey.shade400,
    ),
  );

  if (imageData == null || imageData.isEmpty) {
    return Image.asset('assets/default.png'); // Default image widget
  }

  // Check if it's just a filename (ends with image extension)
  if (imageData.endsWith('.jpg') ||
      imageData.endsWith('.jpeg') ||
      imageData.endsWith('.png') ||
      imageData.endsWith('.gif')) {

    // If it's just a filename, prepend your images directory path
    if (!imageData.contains('/')) {
      return Image.asset('assets/$imageData'); // Asset image widget
      // Or for network images: return Image.network('https://yourserver.com/images/$imageData');
    }
  }

  // Check if it's base64 (usually starts with data: or is very long)
  if (imageData.startsWith('data:image/')) {
    // Handle base64 image
    String base64String = imageData.split(',')[1]; // Remove data:image/...;base64, part
    return Image.memory(base64Decode(base64String));
  }

  // If it's a network URL
  if (imageData.startsWith('http')) {
    return Image.network(imageData);
  }

  // If it's a local file path
  if (imageData.startsWith('/')) {
    return Image.file(File(imageData));
  }

  // Fallback
  print('Unrecognized image format: ${imageData.length > 50 ? imageData.substring(0, 50) : imageData}...');
  return Image.asset('assets/default.png'); // Default widget
  // Default error widget
  final defaultErrorWidget = errorWidget ?? Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: defaultBorderRadius,
      border: Border.all(color: Colors.red.shade300),
    ),
    child: Icon(
      Icons.broken_image,
      size: width * 0.4,
      color: Colors.red.shade400,
    ),
  );

  // Handle empty or null image data
  if (imageData.isEmpty) {
    return defaultPlaceholder;
  }

  // Handle data URL format (data:image/jpeg;base64,...)
  if (imageData.startsWith('data:image')) {
    return _buildBase64Image(
      imageData,
      width: width,
      height: height,
      fit: fit,
      borderRadius: defaultBorderRadius,
      errorWidget: defaultErrorWidget,
    );
  }

  // Handle pure base64 strings
  if (isValidBase64(imageData)) {
    return _buildBase64Image(
      imageData,
      width: width,
      height: height,
      fit: fit,
      borderRadius: defaultBorderRadius,
      errorWidget: defaultErrorWidget,
    );
  }

  // Handle local file paths
  if (imageData.startsWith('/') || imageData.contains('\\')) {
    final file = File(imageData);
    if (file.existsSync()) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: defaultBorderRadius,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: defaultBorderRadius,
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading file image: $error');
              return defaultErrorWidget;
            },
          ),
        ),
      );
    }
  }

  // Handle network URLs
  if (imageData.startsWith('http')) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: defaultBorderRadius,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: defaultBorderRadius,
        child: Image.network(
          imageData,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading network image: $error');
            return defaultErrorWidget;
          },
        ),
      ),
    );
  }

  String safeTruncate(String str, int maxLength) {
    if (str.isEmpty) return str;
    return str.length <= maxLength ? str : str.substring(0, maxLength);
  }

// Usage:
  print('Unrecognized image format: ${safeTruncate(imageData, 50)}...');
  // If none of the above, return error widget
 // print('Unrecognized image format: ${imageData.substring(0, 50)}...');
  return defaultErrorWidget;
}

/// FIXED: Helper function to build base64 images
Widget _buildBase64Image(
    String imageData, {
      required double width,
      required double height,
      required BoxFit fit,
      required BorderRadius borderRadius,
      required Widget errorWidget,
    }) {
  try {
    String base64String = imageData;

    // Extract base64 part if it's a data URL
    if (imageData.startsWith('data:image')) {
      final parts = imageData.split(',');
      if (parts.length != 2) {
        throw Exception('Invalid data URL format');
      }
      base64String = parts[1];
    }

    // Decode base64 to bytes
    final Uint8List bytes = base64Decode(base64String);

    // Validate that we have actual image data
    if (bytes.isEmpty) {
      throw Exception('Empty image data');
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Image.memory(
          bytes,
          width: 30,
          height: 30,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            print('Error displaying base64 image: $error');
            return errorWidget;
          },
        ),
      ),
    );
  } catch (e) {
    print('Error processing base64 image: $e');
    return errorWidget;
  }
}

/// IMPROVED: Add Rucher function with better error handling
Future<void> addRucherWithImage(
    String apiculteurId,
    String newRucherId,
    String address,
    String description,
    XFile? imageFile,
    DatabaseReference apiculteursRef) async {

  try {
    String imageData = '';

    if (imageFile != null) {
      print('Converting image to base64...');

      // Convert image to base64 with proper data URL format
      imageData = await convertImageToBase64(imageFile);
      print('Base64 conversion successful, length: ${imageData.length}');

      // Validate the base64 data
      String? validatedImageData = validateAndCleanBase64Image(imageData);
      if (validatedImageData != null) {
        imageData = validatedImageData;
        print('Base64 validation successful');
      } else {
        print('Base64 validation failed, proceeding without image');
        imageData = '';
      }
    }

    // Save the rucher data to Firebase
    await apiculteursRef.child('$apiculteurId/$newRucherId').set({
      'address': address.trim(),
      'desc': description.trim(),
      'pic': imageData, // Store validated base64 data
    });

    print('Rucher added successfully with image data length: ${imageData.length}');

  } catch (e) {
    print('Error adding rucher: $e');
    throw e; // Re-throw to handle in UI
  }
}

/// Utility function to validate and clean base64 image data before saving
String? validateAndCleanBase64Image(String imageData) {
  if (imageData.isEmpty) return null;

  try {
    // If it's already a proper data URL, validate and return
    if (imageData.startsWith('data:image')) {
      final parts = imageData.split(',');
      if (parts.length == 2 && isValidBase64(parts[1])) {
        return imageData;
      }
      throw Exception('Invalid data URL format');
    }

    // If it's pure base64, validate and add proper prefix
    if (isValidBase64(imageData)) {
      // Default to JPEG if we can't determine the type
      return 'data:image/jpeg;base64,$imageData';
    }

    throw Exception('Invalid base64 data');
  } catch (e) {
    print('Error validating base64 image: $e');
    return null;
  }
}

/// Enhanced image picker dialog with preview
Future<XFile?> showImagePickerDialog(BuildContext context) async {
  return await showDialog<XFile?>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 85,
                );
                Navigator.of(context).pop(pickedFile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () async {
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 85,
                );
                Navigator.of(context).pop(pickedFile);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}

/// Image preview widget with edit/remove options
class ImagePreviewWidget extends StatelessWidget {
  final String? imageData;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final double width;
  final double height;

  const ImagePreviewWidget({
    Key? key,
    this.imageData,
    this.onEdit,
    this.onRemove,
    this.width = 150,
    this.height = 150,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            buildImageFromBase64OrPath(
              imageData ?? '',
              width: width,
              height: height,
            ),
            if (imageData != null && imageData!.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: onRemove,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Change'),
              onPressed: onEdit,
            ),
            if (imageData != null && imageData!.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Remove', style: TextStyle(color: Colors.red)),
                onPressed: onRemove,
              ),
          ],
        ),
      ],
    );
  }
}
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

    rucherData.forEach((key, value) {
      String keyStr = key.toString();

      if (keyStr.startsWith('ruche') && value is Map<dynamic, dynamic>) {
        // Parse all data points for this ruche
        Map<String, RucheDataPoint> dataPoints = {};
        value.forEach((entryKey, entryValue) {
          if (entryValue is String && entryValue.contains('/')) {
            try {
              dataPoints[entryKey.toString()] = RucheDataPoint.fromString(entryValue);
            } catch (e) {
              print('Error parsing ruche data: $e');
            }
          }
        });

        // Create temporary ruche with parsed data
        RucheInfo tempRuche = RucheInfo(
          id: keyStr,
          rucherId: '',
          apiculteurId: '',
          dataPoints: dataPoints,
        );

        // Use the same logic as hasActiveAlert (alert=1 AND couvercle=1)
        if (tempRuche.hasActiveAlert) {
          alertCount++;
        }
      }
    });

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
    // If user is apiculteur, only load their data
    if (_userRole == UserRole.apiculteur && _currentApiculteurId.isNotEmpty) {
      final specificApiculteurRef = _apiculteursRef.child(_currentApiculteurId);
      specificApiculteurRef.get().then((apiculteurSnapshot) {
        if (apiculteurSnapshot.exists && apiculteurSnapshot.value != null) {
          _loadSpecificApiculteurFromSnapshot(apiculteurSnapshot, _currentApiculteurId);
        }
      });
      return;
    }

// Helper method - ADD THIS AS A CLASS METHOD in your widget class
    String? getCurrentApiculteurKey(String email) {
      // This should map the user's email to their apiculteur key
      // For example, if "api1@example.com" maps to "api_001"
      // You might have a mapping like:
      final emailToApiculteurMap = {
        'api1@example.com': 'api_001',
        'api2@example.com': 'api_002',
        // ... etc
      };

      return emailToApiculteurMap[email];

      // OR if you have this mapping in your database, fetch it from there
      // OR if the email directly corresponds to the apiculteur key somehow
    }

    // ✅ ADMIN ONLY: Load all apiculteurs
    if (_userRole == UserRole.admin) {
      setState(() {
        _apiculteurs = [];
        _rucherToApiculteurMap.clear();

        if (snapshot.exists && snapshot.value != null) {
          final map = snapshot.value as Map<dynamic, dynamic>;
          map.forEach((key, value) {
            if (key.toString().startsWith('api')) {
              final List<RucherInfo> ruchersList = [];
              if (value is Map<dynamic, dynamic>) {
                value.forEach((rKey, rValue) {
                  if (rKey.toString().startsWith('rucher') && rValue is Map<dynamic, dynamic>) {
                    int rucheCount = 0;
                    rValue.forEach((key, _) {
                      if (key.toString().startsWith('ruche')) {
                        rucheCount++;
                      }
                    });

                    List<RucheInfo> ruches = _loadRuchesForRucher(rValue, rKey.toString(), key.toString());
                    int alertCount = _countRucherAlerts(rValue);

                    _rucherToApiculteurMap[rKey.toString()] = key.toString();

                    ruchersList.add(RucherInfo(
                      id: rKey.toString(),
                      address: rValue['address'] ?? '',
                      description: rValue['desc'] ?? '',
                      picUrl: rValue['pic'] ?? '',
                      rucheCount: rucheCount,
                      ruches: ruches,
                      alertCount: alertCount,
                      isExpanded: false,
                    ));
                  }
                });
              }

              final sortedRuchers = _sortRuchers(ruchersList);

              _apiculteurs.add(ApiculteurWithRuchers(
                id: key.toString(),
                nom: value['nom'] ?? '',
                prenom: value['prenom'] ?? '',
                ruchers: sortedRuchers,
              ));
            }
          });

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
        }

        _isLoading = false;
      });
    }
// ✅ REGULAR USER: Load only current apiculteur's data
    else {
      setState(() {
        _apiculteurs = [];
        _rucherToApiculteurMap.clear();

        if (snapshot.exists && snapshot.value != null) {
          final map = snapshot.value as Map<dynamic, dynamic>;

          // Only process the current user's apiculteur data
          final currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
          final currentApiculteurKey = getCurrentApiculteurKey(currentUserEmail); // Fixed: removed underscore

          if (currentApiculteurKey != null && map.containsKey(currentApiculteurKey)) {
            final value = map[currentApiculteurKey];
            final List<RucherInfo> ruchersList = [];

            if (value is Map<dynamic, dynamic>) {
              value.forEach((rKey, rValue) {
                if (rKey.toString().startsWith('rucher') && rValue is Map<dynamic, dynamic>) {
                  int rucheCount = 0;
                  rValue.forEach((key, _) {
                    if (key.toString().startsWith('ruche')) {
                      rucheCount++;
                    }
                  });

                  List<RucheInfo> ruches = _loadRuchesForRucher(rValue, rKey.toString(), currentApiculteurKey);
                  int alertCount = _countRucherAlerts(rValue);

                  _rucherToApiculteurMap[rKey.toString()] = currentApiculteurKey;

                  ruchersList.add(RucherInfo(
                    id: rKey.toString(),
                    address: rValue['address'] ?? '',
                    description: rValue['desc'] ?? '',
                    picUrl: rValue['pic'] ?? '',
                    rucheCount: rucheCount,
                    ruches: ruches,
                    alertCount: alertCount,
                    isExpanded: false,
                  ));
                }
              });
            }

            final sortedRuchers = _sortRuchers(ruchersList);

            // Add only the current user's apiculteur
            _apiculteurs.add(ApiculteurWithRuchers(
              id: currentApiculteurKey,
              nom: value['nom'] ?? '',
              prenom: value['prenom'] ?? '',
              ruchers: sortedRuchers,
            ));

            // Set the current apiculteur ID
            _currentApiculteurId = currentApiculteurKey;
          }
        }

        _isLoading = false;
      });
    }


  }


  Future<void> _addRucher(ApiculteurWithRuchers apiculteur) async {
    final addressController = TextEditingController();
    final descController = TextEditingController();

    XFile? imageFile;
    String? selectedImagePath; // To show preview

    int nextRucherNumber = apiculteur.ruchers.length + 1;
    String newRucherId = 'rucher_${nextRucherNumber.toString().padLeft(3, '0')}';

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Make dialog stateful to update image preview
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Rucher'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image preview section
                    if (selectedImagePath != null) ...[
                      Container(
                        height: 12,
                        width: 12,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(selectedImagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selected: ${imageFile?.name ?? ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Image picker buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final pickedFile = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1024,
                                maxHeight: 1024,
                                imageQuality: 85,
                              );
                              if (pickedFile != null) {
                                imageFile = pickedFile;
                                selectedImagePath = pickedFile.path;
                                setDialogState(() {}); // Update dialog UI
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final pickedFile = await picker.pickImage(
                                source: ImageSource.camera,
                                maxWidth: 1024,
                                maxHeight: 1024,
                                imageQuality: 85,
                              );
                              if (pickedFile != null) {
                                imageFile = pickedFile;
                                selectedImagePath = pickedFile.path;
                                setDialogState(() {}); // Update dialog UI
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    // Remove image button (if image is selected)
                    if (selectedImagePath != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          imageFile = null;
                          selectedImagePath = null;
                          setDialogState(() {}); // Update dialog UI
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: addressController.text.trim().isEmpty || descController.text.trim().isEmpty
                      ? null
                      : () => Navigator.of(context).pop(true),
                  child: const Text('Add Rucher'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        String imageData = '';

        if (imageFile != null) {
          // Convert image to base64
          print('Converting image to base64...');
          imageData = await convertImageToBase64(imageFile!);
          print('Base64 conversion successful, length: ${imageData.length}');

          // Add data URL prefix for proper display
          if (!imageData.startsWith('data:image')) {
            // Determine MIME type based on file extension
            String mimeType = 'image/jpeg'; // default
            String fileName = imageFile!.name.toLowerCase();
            if (fileName.endsWith('.png')) {
              mimeType = 'image/png';
            } else if (fileName.endsWith('.gif')) {
              mimeType = 'image/gif';
            } else if (fileName.endsWith('.webp')) {
              mimeType = 'image/webp';
            }

            imageData = 'data:$mimeType;base64,$imageData';
          }
        }

        // Save the rucher data to Firebase
        await _apiculteursRef.child('${apiculteur.id}/$newRucherId').set({
          'address': addressController.text.trim(),
          'desc': descController.text.trim(),
          'pic': imageData, // Store base64 data with proper prefix
        });

        // Close loading dialog
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rucher "$newRucherId" added successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        print('Rucher added successfully with image data length: ${imageData.length}');

      } catch (e) {
        // Close loading dialog
        Navigator.of(context).pop();

        print('Error adding rucher: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding rucher: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
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
      backgroundColor: Colors.amber.shade50, // ✅ This sets the page background
      appBar: AppBar(
        title: Text(
            _userRole == UserRole.admin ? 'Listes des Ruchers (Admin)' : 'Mes Ruchers'
        ),
        backgroundColor: Colors.amber.shade50, // optional – same as scaffold
        foregroundColor: Colors.black,
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
          // Alert banner
          if (_getTotalActiveAlerts() > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
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
          // List of apiculteurs and ruchers
          Expanded(
            child: ListView.builder(
              itemCount: _apiculteurs.length,
              itemBuilder: (context, index) {
                final apiculteur = _apiculteurs[index];

                // Calculate total alerts for this apiculteur
                int apiculteurAlerts = apiculteur.ruchers.fold(
                  0,
                      (total, rucher) => total + rucher.alertCount,
                );

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  elevation: apiculteurAlerts > 0 ? 4 : 2,
                  color: apiculteurAlerts > 0 ? Colors.white: null,
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
                              '⚠️ $apiculteurAlerts', // ✅ Fixed: Use apiculteurAlerts instead of _getTotalActiveAlerts()
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
                      '${apiculteur.ruchers.length} ruchers${apiculteurAlerts > 0 ? ' - $apiculteurAlerts alerte(s)' : ''}', // ✅ Fixed: Use apiculteurAlerts
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
                    initiallyExpanded: apiculteur.isExpanded || apiculteurAlerts > 0, // ✅ Fixed: Use apiculteurAlerts instead of _getTotalActiveAlerts()
                    onExpansionChanged: (expanded) {
                      setState(() {
                        apiculteur.isExpanded = expanded;
                      });
                    },
                    children: apiculteur.ruchers.map((rucher) {
                      return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      elevation: rucher.alertCount > 0 ? 3 : 1,
                      child: Container(
                      decoration: rucher.alertCount > 0
                      ?  BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade300, // <-- darker amber (more saturated)
                          const Color(0xFFFFF8E1), // <-- keep pale yellow (amber.shade50)
                        ], // amber.shade100 & shade50
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      ),
                      )
                          : null,
                      child: Padding(

                      padding: const EdgeInsets.all(12.0),
                          child: Column( // Changed from Row to Column for better mobile layout
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // First row: Image and main content
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image container with fixed size
                                  Container(
                                    width: 80, // Reduced from 100
                                    height: 80, // Reduced from 100
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: buildImageFromBase64OrPath(
                                        rucher.picUrl,
                                        width: 80,
                                        height: 80,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12), // Reduced from 16

                                  // Flexible content area
                                  Expanded( // This is crucial - it prevents overflow
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Title row with alert indicator
                                        Row(
                                          children: [
                                            Flexible( // Allow text to wrap if needed
                                              child: Text(
                                                rucher.id,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: rucher.alertCount > 0 ? Colors.red.shade800 : null,
                                                ),
                                                overflow: TextOverflow.ellipsis, // Handle long text
                                              ),
                                            ),
                                            // Enhanced alert indicator
                                            if (rucher.alertCount > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Reduced padding
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
                                                child: Text(
                                                  '⚠️ ${rucher.alertCount}',
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
                                        const SizedBox(height: 8),

                                        // Address with proper text wrapping
                                        Text(
                                          '📍 ${rucher.address}',
                                          style: const TextStyle(fontSize: 14),
                                          maxLines: 2, // Allow up to 2 lines
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),

                                        // Description with proper text wrapping
                                        Text(
                                          '📝 ${rucher.description}',
                                          style: const TextStyle(fontSize: 14),
                                          maxLines: 2, // Allow up to 2 lines
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),

                                        // Ruche count
                                        Text(
                                          '🐝 Ruches: ${rucher.rucheCount}',
                                          style: const TextStyle(fontSize: 14),
                                        ),

                                        // Show alert text if there are alerts
                                        if (rucher.alertCount > 0) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '🚨 ${rucher.alertCount} alerte(s) active(s)',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Second row: Action buttons (moved below to avoid crowding)
                              if (_userRole == UserRole.admin ||
                                  (apiculteur.id == _currentApiculteurId && _userRole == UserRole.apiculteur)) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Modifier'),
                                      onPressed: () => _editRucher(rucher),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                      label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                                      onPressed: () => _deleteRucher(rucher),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
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
class RucheContent extends StatelessWidget {
  const RucheContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Text("Welcome to Ruche Page"),
        // Add more widgets here
      ],
    );
  }
}

