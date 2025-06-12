import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'presence_service.dart';
import 'profile_service.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final PresenceService _presence;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    PresenceService? presenceService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _presence = presenceService ?? PresenceService();

  // 🔹 Connexion avec Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!doc.exists) {
          await ProfileService().createProfile(
            user.uid,
            user.displayName ?? '',
            user.photoURL ?? '',
            '',
          );
        }
        _presence.init(user.uid);
      }
      return user;
    } catch (e) {
      debugPrint("❌ Erreur d'authentification Google : $e");
      return null;
    }
  }

  // 🔹 Connexion avec Apple
  Future<User?> signInWithApple() async {
    try {
      if (!Platform.isIOS && !Platform.isMacOS) {
        throw UnsupportedError("Apple Sign-In n'est disponible que sur iOS/macOS.");
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user != null) {
        _presence.init(user.uid);
      }
      return user;
    } catch (e) {
      debugPrint("❌ Erreur d'authentification Apple : $e");
      return null;
    }
  }

  // 🔹 Inscription avec email et mot de passe
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        _presence.init(user.uid);
      }
      return user;
    } catch (e) {
      debugPrint("❌ Erreur d'inscription : $e");
      return null;
    }
  }

  // 🔹 Connexion avec email et mot de passe
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        _presence.init(user.uid);
      }
      return user;
    } catch (e) {
      debugPrint("❌ Erreur d'authentification Email : $e");
      return null;
    }
  }

  // 🔹 Déconnexion
  Future<void> signOut({FirebaseFirestore? firestore}) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      await db
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'online': false});
      _presence.dispose();
      await _auth.signOut();
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      debugPrint("✅ Déconnexion réussie");
    } catch (e) {
      debugPrint("❌ Erreur lors de la déconnexion : $e");
    }
  }
}
