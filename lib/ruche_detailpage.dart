import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'login_page.dart';

class RucheDetailPage extends StatefulWidget {
  final String apiculteurId;
  final String rucherId;
  final String rucheId;

  const RucheDetailPage({
    Key? key,
    required this.apiculteurId,
    required this.rucherId,
    required this.rucheId
  }) : super(key: key);

  @override
  State<RucheDetailPage> createState() => _RucheDetailPageState();
}

class _RucheDetailPageState extends State<RucheDetailPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref('apiculteurs');
  User? _currentUser;
  List<DataPoint> _dataPoints = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _debugInfo = ''; // Added for debugging

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    setState(() => _isLoading = true);
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      _navigateToLogin();
    } else {
      _fetchData();
    }
  }

  void _navigateToLogin() {
    Future.delayed(Duration.zero, () {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => LoginPage(),
      ));
    });
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      _navigateToLogin();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de déconnexion : $e';
      });
    }
  }

  Future<void> _fetchData() async {
    try {
      setState(() => _isLoading = true);

      // Build the path from the three IDs
      final ref = _database
          .child(widget.apiculteurId)
          .child(widget.rucherId)
          .child(widget.rucheId);

      // Store path for debugging
      final path = '${widget.apiculteurId}/${widget.rucherId}/${widget.rucheId}';
      setState(() {
        _debugInfo = 'Fetching data from path: $path';
      });

      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) {
        setState(() {
          _errorMessage = 'Aucune donnée trouvée pour cette ruche';
          _isLoading = false;
        });
        return;
      }

      final Map<dynamic, dynamic> rucheData = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _debugInfo += '\nFound data with ${rucheData.length} entries';
      });

      List<DataPoint> points = [];

      // Process each data entry in the ruche data
      rucheData.forEach((key, value) {
        // Skip non-data entries like 'desc'
        if (key == 'desc') return;

        try {
          // Parse the string format: "472025-04-03T13:34:55Z/86/58/0/0"
          final String dataStr = value.toString();
          final parts = dataStr.split('/');

          if (parts.length >= 3) {
            String dateStr = parts[0];
            // Remove the leading '47' prefix if present
            if (dateStr.startsWith('47')) {
              dateStr = dateStr.substring(2);
            }

            final tempStr = parts[1];
            final humStr = parts[2];

            DateTime date;
            try {
              date = DateTime.parse(dateStr);
            } catch (e) {
              print('Date parsing error: $e for string: $dateStr');
              date = DateTime.now();
            }

            points.add(DataPoint(
              id: key.toString(),
              date: date,
              temperature: double.tryParse(tempStr) ?? 0.0,
              humidity: double.tryParse(humStr) ?? 0.0,
            ));
          }
        } catch (e) {
          print('Error parsing data point $key: $e');
        }
      });

      // Sort by date
      points.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _dataPoints = points;
        _isLoading = false;
        _errorMessage = '';
        _debugInfo += '\nProcessed ${points.length} data points';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de la récupération des données: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ruche ${widget.rucheId}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            // Show debug info when there's an error
            Text(_debugInfo, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchData, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    if (_dataPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Aucune donnée disponible.'),
            const SizedBox(height: 16),
            // Show path info even when no data
            Text('Path: ${widget.apiculteurId}/${widget.rucherId}/${widget.rucheId}',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Show path info for debugging
          Text('Path: ${widget.apiculteurId}/${widget.rucherId}/${widget.rucheId}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem(Colors.red, 'Température'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.blue, 'Humidité'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildChart()),
          const SizedBox(height: 16),
          _buildDataTable(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, _) {
                if (value.toInt() >= 0 && value.toInt() < _dataPoints.length) {
                  final date = _dataPoints[value.toInt()].date;
                  return Text(DateFormat('MM/dd').format(date), style: const TextStyle(fontSize: 10));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, _) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (_dataPoints.length - 1).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(_dataPoints.length, (i) => FlSpot(i.toDouble(), _dataPoints[i].temperature)),
            color: Colors.red,
            barWidth: 3,
            isCurved: true,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: List.generate(_dataPoints.length, (i) => FlSpot(i.toDouble(), _dataPoints[i].humidity)),
            color: Colors.blue,
            barWidth: 3,
            isCurved: true,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Expanded(
      child: Card(
        elevation: 4,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Temp. (°C)')),
              DataColumn(label: Text('Humid. (%)')),
            ],
            rows: _dataPoints.map((point) {
              return DataRow(cells: [
                DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(point.date))),
                DataCell(Text(point.temperature.toStringAsFixed(1))),
                DataCell(Text(point.humidity.toStringAsFixed(1))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

// Data model
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