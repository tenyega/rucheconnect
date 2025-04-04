import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'details_page.dart';
import 'login_page.dart'; // Import your login page

class TemperatureHumidityChart extends StatefulWidget {
  final String title;

  const TemperatureHumidityChart({Key? key, this.title = 'Graph'}) : super(key: key);

  @override
  State<TemperatureHumidityChart> createState() => _TemperatureHumidityChartState();
}

class _TemperatureHumidityChartState extends State<TemperatureHumidityChart> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref('test');
  final FirebaseAuth _auth = FirebaseAuth.instance; // Add Firebase Auth instance
  List<DataPoint> _dataPoints = [];
  bool _isLoading = true;
  String _errorMessage = '';
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  // Check if user is authenticated
  Future<void> _checkAuthentication() async {
    setState(() {
      _isLoading = true;
    });

    // Get current user
    _currentUser = _auth.currentUser;

    if (_currentUser == null) {
      // User is not authenticated, redirect to login page
      _navigateToLogin();
    } else {
      // User is authenticated, fetch data
      _fetchData();
    }
  }

  // Navigate to login page
  void _navigateToLogin() {
    // Use Future.delayed to prevent calling setState during build
    Future.delayed(Duration.zero, () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginPage(), // Replace with your login page widget
        ),
      );
    });
  }

  // Sign out function
  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      _navigateToLogin();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error signing out: $e';
      });
    }
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

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

        List<DataPoint> points = [];
        for (String id in allIds) {
          // Parse string values to appropriate types
          final dateStr = dateData?[id]?.toString() ?? 'N/A';
          final humidityStr = humidityData?[id]?.toString() ?? '0';
          final temperatureStr = temperatureData?[id]?.toString() ?? '0';

          // Parse or convert date string to DateTime
          DateTime date;
          try {
            // Use DateTime.parse for ISO 8601 format dates like "2025-02-21T16:21:08Z"
            date = DateTime.parse(dateStr);
          } catch (e) {
            // If parsing fails, use current date
            print('Failed to parse date: $dateStr, error: $e');
            date = DateTime.now();
          }

          // Parse numeric values
          final humidity = double.tryParse(humidityStr) ?? 0.0;
          final temperature = double.tryParse(temperatureStr) ?? 0.0;

          points.add(DataPoint(
            id: id,
            date: date,
            temperature: temperature,
            humidity: humidity,
          ));
        }

        // Sort by ID (which should correspond to timestamp)
        points.sort((a, b) => (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0));

        setState(() {
          _dataPoints = points;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor:  Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: 'Refresh data',
          ),
          // Add logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign out',
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
    if (_dataPoints.isEmpty) {
      return const Center(child: Text('No data available for chart'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display user email
          if (_currentUser != null)

          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem(Colors.red, 'Temperature'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.blue, 'Humidity'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < _dataPoints.length) {
                          // Show date for every 5th point or adjust as needed
                          if (value.toInt() % 5 == 0 || value.toInt() == _dataPoints.length - 1) {
                            final date = _dataPoints[value.toInt()].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MM/dd').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: _dataPoints.length.toDouble() - 1,
                lineBarsData: [
                  // Temperature Line
                  LineChartBarData(
                    spots: List.generate(
                      _dataPoints.length,
                          (index) => FlSpot(
                        index.toDouble(),
                        _dataPoints[index].temperature,
                      ),
                    ),
                    color: Colors.red,
                    barWidth: 3,
                    isCurved: true,
                    dotData: FlDotData(show: false),
                  ),
                  // Humidity Line
                  LineChartBarData(
                    spots: List.generate(
                      _dataPoints.length,
                          (index) => FlSpot(
                        index.toDouble(),
                        _dataPoints[index].humidity,
                      ),
                    ),
                    color: Colors.blue,
                    barWidth: 3,
                    isCurved: true,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Convert DataPoint objects to Map<String, dynamic> with string values
                List<Map<String, dynamic>> dataEntriesMaps = _dataPoints.map((point) => {
                  'id': point.id,
                  'date': point.date.toIso8601String(),  // Format as ISO 8601 string
                  'temperature': point.temperature.toString(),
                  'humidity': point.humidity.toString(),
                }).toList();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsPage(dataEntries: dataEntriesMaps),
                  ),
                );
              },
              child: const Text("View Details"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

// Data model class
class DataPoint {
  final String id;
  final DateTime date;
  final double temperature;
  final double humidity;

  DataPoint({
    required this.id,
    required this.date,
    required this.temperature,
    required this.humidity,
  });
}