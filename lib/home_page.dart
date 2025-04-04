import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:tp_flutter/temperatureHumidityChart.dart';
import 'login_page.dart';
import 'details_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref('test');
  List<Map<String, dynamic>> _dataEntries = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

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


        List<Map<String, dynamic>> entries = [];
        for (String id in allIds) {
          //formating the date to a proper date format
          String formattedDate;
          try {
            // First try parsing if it's already in ISO format
            DateTime dateTime = DateTime.parse(dateData?[id]);
            formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
          } catch (e) {
            // If entry['date'] is already formatted, just use it
            formattedDate = dateData?[id];
          }
          entries.add({
            'id': id,
            'date': formattedDate ?? 'N/A',
            'humidity': humidityData?[id]?.toString() ?? 'N/A',
            'temperature': temperatureData?[id]?.toString() ?? 'N/A',
          });
        }

        entries.sort((a, b) => (int.tryParse(a['id']) ?? 0).compareTo(int.tryParse(b['id']) ?? 0));

        setState(() {
          _dataEntries = entries;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No data available';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching data: $e';
      });
      print('Error fetching data: $e');
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: 'Refresh data',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchData, child: const Text('Try Again')),
          ],
        ),
      );
    }
    if (_dataEntries.isEmpty) {
      return const Center(child: Text('No data entries found'));
    }

    final latestEntry = _dataEntries.last;

    return Align(
      alignment: Alignment(0, -0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Temp Benchmark ---- 50 deg", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text("Latest Reading:", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text("📅 Date: ${latestEntry['date']}", style: Theme.of(context).textTheme.bodyMedium),
            Text("💧 Humidity: ${latestEntry['humidity']}", style: Theme.of(context).textTheme.bodyMedium),
            Text("🌡️ Temperature: ${latestEntry['temperature']}", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TemperatureHumidityChart()),
                  );
                },
                child: const Text("View Graph"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
