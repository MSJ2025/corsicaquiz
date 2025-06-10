import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:corsicaquiz/services/auth_service.dart';
import 'package:corsicaquiz/services/presence_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockPresenceService extends Mock implements PresenceService {}

void main() {
  test('signOut appelle les services nécessaires', () async {
    final auth = MockFirebaseAuth();
    final google = MockGoogleSignIn();
    final presence = MockPresenceService();

    when(() => google.isSignedIn()).thenAnswer((_) async => true);

    final service = AuthService(
      auth: auth,
      googleSignIn: google,
      presenceService: presence,
    );

    await service.signOut();

    verify(() => presence.dispose()).called(1);
    verify(() => auth.signOut()).called(1);
    verify(() => google.isSignedIn()).called(1);
    verify(() => google.signOut()).called(1);
  });
}
