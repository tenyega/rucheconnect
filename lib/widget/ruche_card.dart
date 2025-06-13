import 'package:flutter/material.dart';
import 'package:tp_flutter/ruche.dart'; // This must include RucheInfo and RucheDataPoint

class RucheCard extends StatelessWidget {
  final RucheInfo ruche;

  const RucheCard({Key? key, required this.ruche}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final latestData = ruche.getLatestDataPoint();

    return Card(
      child: ListTile(
        title: Text(ruche.id),
        subtitle: Text(
          'Temp: ${latestData?.temperature ?? "-"}°C, Hum: ${latestData?.humidity ?? "-"}%',
        ),
      ),
    );
  }
}
