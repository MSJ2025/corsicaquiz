import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'presence_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final _presence = PresenceService();

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
  Future<void> signOut() async {
    try {
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