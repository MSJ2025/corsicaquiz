import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corsicaquiz/screens/login_screen.dart';
import 'package:corsicaquiz/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/foundation.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {

  testWidgets('LoginScreen affiche le bouton Connexion', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text("Créer un compte"), findsOneWidget);
  });

  testWidgets('Affiche un SnackBar si la connexion Google échoue', (tester) async {
    final mockAuth = MockAuthService();
    when(() => mockAuth.signInWithGoogle()).thenAnswer((_) async => null);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: mockAuth)));

    await tester.tap(find.text('Se connecter avec Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Échec de la connexion'), findsOneWidget);
  });

  testWidgets('Affiche un SnackBar si la connexion Apple échoue', (tester) async {
    final mockAuth = MockAuthService();
    when(() => mockAuth.signInWithApple()).thenAnswer((_) async => null);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: mockAuth)));

    await tester.tap(find.text('Se connecter avec Apple'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Échec de la connexion'), findsOneWidget);
  });
}
