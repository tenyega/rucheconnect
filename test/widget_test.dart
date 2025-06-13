import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:tp_flutter/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Firebase before tests
    await Firebase.initializeApp();
  });

  testWidgets('RucheConnectée app loads successfully', (WidgetTester tester) async {
    // Mock a signed-in user for FirebaseAuth if needed
    final mockUser = MockUser(isAnonymous: false, uid: 'test-user');
    final mockAuth = MockFirebaseAuth(mockUser: mockUser);

    // You might need to inject mockAuth into your app, depending on your AuthGate implementation.
    // If not injectable, test a lower-level widget that doesn't depend on Firebase.

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Look for a known text to confirm rendering
    expect(find.text('Mes Ruchers'), findsOneWidget);
  });
}
