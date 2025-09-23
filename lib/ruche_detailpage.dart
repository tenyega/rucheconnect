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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Ruche ${widget.rucheId}'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            color: Colors.black,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            color: Colors.black,
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
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _debugInfo,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_dataPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aucune donnée disponible.',
              style: TextStyle(
                color: Colors.amber.shade800,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sur : ${widget.apiculteurId}/${widget.rucherId}/${widget.rucheId}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Path info with updated styling
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Path: ${widget.apiculteurId}/${widget.rucherId}/${widget.rucheId}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          // Legend with updated styling
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.red, 'Température'),
                const SizedBox(width: 24),
                _buildLegendItem(Colors.blue, 'Humidité'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Chart with updated container
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildChart(),
            ),
          ),
          const SizedBox(height: 16),
          // Data table with updated styling
          Expanded(
            flex: 1,
            child: _buildDataTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade300,
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: Colors.grey.shade300,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, _) {
                if (value.toInt() >= 0 && value.toInt() < _dataPoints.length) {
                  final date = _dataPoints[value.toInt()].date;
                  return Text(
                    DateFormat('MM/dd').format(date),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade400),
        ),
        minX: 0,
        maxX: (_dataPoints.length - 1).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(_dataPoints.length, (i) => FlSpot(i.toDouble(), _dataPoints[i].temperature)),
            color: Colors.red,
            barWidth: 3,
            isCurved: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.withOpacity(0.1),
            ),
          ),
          LineChartBarData(
            spots: List.generate(_dataPoints.length, (i) => FlSpot(i.toDouble(), _dataPoints[i].humidity)),
            color: Colors.blue,
            barWidth: 3,
            isCurved: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.table_chart,
                    color: Colors.amber.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Données détaillées',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: MaterialStateProperty.all(Colors.amber.shade50),
                  columns: [
                    DataColumn(
                      label: Text(
                        'Date',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Temp. (°C)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Humid. (%)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                  rows: _dataPoints.map((point) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(point.date),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                        DataCell(
                          Text(
                            point.temperature.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            point.humidity.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
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