import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp_flutter/ruche.dart'; // Make sure this contains RucheInfo
import 'package:tp_flutter/widget/ruche_card.dart'; // ✅ new widget you just created

void main() {
  testWidgets('RucheCard displays temperature and humidity', (WidgetTester tester) async {
    final rucheInfo = RucheInfo(
      id: 'ruche_001',
      rucherId: 'rucher_001',
      apiculteurId: 'api_001',
      dataPoints: {
        '1000': RucheDataPoint(
          timestamp: DateTime.now(),
          temperature: 25,
          humidity: 70,
          couvercle: 0,
          alert: 0,
        ),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RucheCard(ruche: rucheInfo),
        ),
      ),
    );

    expect(find.text('ruche_001'), findsOneWidget);
    expect(find.textContaining('Temp: 25°C'), findsOneWidget);
    expect(find.textContaining('Hum: 70%'), findsOneWidget);
  });
}
