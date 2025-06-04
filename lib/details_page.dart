import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_page.dart';

class DetailsPage extends StatefulWidget {
  final List<Map<String, dynamic>> dataEntries;

  const DetailsPage({Key? key, required this.dataEntries}) : super(key: key);

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref('test');
  late List<Map<String, dynamic>> _currentData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentData = widget.dataEntries;
  }

  // Method to fetch fresh data
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user is still authenticated
      if (_auth.currentUser == null) {
        _navigateToLogin();
        return;
      }

      DataSnapshot snapshot = await _database.get();
      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> testData = snapshot.value as Map<dynamic, dynamic>;

        Map<dynamic, dynamic>? dateData = testData['date'] as Map<dynamic, dynamic>?;
        Map<dynamic, dynamic>? humidityData = testData['humidity'] as Map<dynamic, dynamic>?;
        Map<dynamic, dynamic>? temperatureData = testData['temperature'] as Map<dynamic, dynamic>?;

        Set<String> allIds = <String>{};
        dateData?.keys.forEach((key) => allIds.add(key.toString()));
        humidityData?.keys.forEach((key) => allIds.add(key.toString()));
        temperatureData?.keys.forEach((key) => allIds.add(key.toString()));

        List<Map<String, dynamic>> freshData = [];
        for (String id in allIds) {
          final dateStr = dateData?[id]?.toString() ?? 'N/A';
          final humidityStr = humidityData?[id]?.toString() ?? '0';
          final temperatureStr = temperatureData?[id]?.toString() ?? '0';

          // Parse date string to DateTime
          DateTime date;
          try {
            date = DateTime.parse(dateStr);
          } catch (e) {
            print('Failed to parse date: $dateStr, error: $e');
            date = DateTime.now();
          }

          freshData.add({
            'id': id,
            'date': date.toIso8601String(),
            'temperature': temperatureStr,
            'humidity': humidityStr,
          });
        }

        // Sort by ID
        freshData.sort((a, b) => (int.tryParse(a['id'] as String) ?? 0)
            .compareTo(int.tryParse(b['id'] as String) ?? 0));

        if (mounted) {
          setState(() {
            _currentData = freshData;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data refreshed')),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data available')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing data: $e')),
        );
      }
      print('Error fetching data: $e');
    }
  }

  // Navigate to login page
  void _navigateToLogin() {
    // Use Future.delayed to prevent calling setState during build
    Future.delayed(Duration.zero, () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
      }
    });
  }

  // Method to sign out
  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      _navigateToLogin();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Widget buildDataRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("READINGS"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          _isLoading
              ? Container(
            padding: const EdgeInsets.all(12),
            child: const CircularProgressIndicator(color: Colors.black),
          )
              : IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchData,
            tooltip: 'Refresh data',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: _signOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _currentData.length,
              itemBuilder: (context, index) {
                final entry = _currentData[index];

                // Formatting the date to a proper date format
                String formattedDate;
                try {
                  // First try parsing if it's already in ISO format
                  DateTime dateTime = DateTime.parse(entry['date']);
                  formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
                } catch (e) {
                  // If entry['date'] is already formatted, just use it
                  formattedDate = entry['date'] ?? 'Unknown date';
                }

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entry on: $formattedDate',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Divider(),
                        buildDataRow(context, 'Humidity:', entry['humidity'] ?? 'N/A'),
                        buildDataRow(context, 'Temperature:', entry['temperature'] ?? 'N/A'),
                      ],
                    ),
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