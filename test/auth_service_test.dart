import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:corsicaquiz/services/auth_service.dart';
import 'package:corsicaquiz/services/presence_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockPresenceService extends Mock implements PresenceService {}
class MockUser extends Mock implements User {}

void main() {
  test('signOut appelle les services nécessaires', () async {
    final auth = MockFirebaseAuth();
    final google = MockGoogleSignIn();
    final presence = MockPresenceService();
    final firestore = FakeFirebaseFirestore();

    when(() => google.isSignedIn()).thenAnswer((_) async => true);
    when(() => google.signOut()).thenAnswer((_) async {});
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => presence.dispose()).thenReturn(null);

    final service = AuthService(
      auth: auth,
      googleSignIn: google,
      presenceService: presence,
    );

    final user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('u1');

    await firestore.collection('users').doc('u1').set({'online': true});

    await service.signOut(firestore: firestore);

    verify(() => presence.dispose()).called(1);
    verify(() => auth.signOut()).called(1);
    verify(() => google.isSignedIn()).called(1);
    verify(() => google.signOut()).called(1);
  });

  test('signOut met le statut en hors ligne', () async {
    final auth = MockFirebaseAuth();
    final google = MockGoogleSignIn();
    final presence = MockPresenceService();
    final firestore = FakeFirebaseFirestore();
    final user = MockUser();

    when(() => google.isSignedIn()).thenAnswer((_) async => false);
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => presence.dispose()).thenReturn(null);
    when(() => user.uid).thenReturn('u1');
    when(() => auth.currentUser).thenReturn(user);

    await firestore.collection('users').doc('u1').set({'online': true});

    final service = AuthService(
      auth: auth,
      googleSignIn: google,
      presenceService: presence,
    );

    await service.signOut(firestore: firestore);

    final doc = await firestore.collection('users').doc('u1').get();
    expect(doc.data()?['online'], false);
  });

  test('signInWithApple renvoie null si la plateforme n\'est pas iOS/macOS', () async {
    final auth = MockFirebaseAuth();
    final service = AuthService(auth: auth);

    final user = await service.signInWithApple();

    expect(user, isNull);
  });
}
