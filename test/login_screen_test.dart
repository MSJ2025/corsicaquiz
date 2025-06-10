import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corsicaquiz/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen affiche le bouton Connexion', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text("Créer un compte"), findsOneWidget);
  });
}
