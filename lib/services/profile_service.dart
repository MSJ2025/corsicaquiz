import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🔹 Vérifie si l'utilisateur a un profil complet
  Future<bool> hasProfile(String uid) async {
    try {
      print("🔎 [Firestore] Vérification du profil pour UID: $uid");

      var doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) {
        print("❌ [Firestore] Aucun profil trouvé !");
        return false;
      }

      final data = doc.data();
      final pseudo = data?['pseudo'] ?? '';
      final isValid = pseudo.toString().trim().isNotEmpty;

      if (isValid) {
        print("✅ [Firestore] Profil complet trouvé !");
      } else {
        print("❌ [Firestore] Profil incomplet (pseudo manquant)");
      }

      return isValid;
    } catch (e) {
      print("⚠️ [Erreur Firestore - hasProfile] $e");
      return false;
    }
  }

  // 🔹 Crée un profil utilisateur
  Future<void> createProfile(String uid, String pseudo, String avatar, String bio) async {
    try {
      print("📝 [Firestore] Création du profil pour UID: $uid");

      await _db.collection('users').doc(uid).set({
        "uid": uid,
        "pseudo": pseudo,
        "avatar": avatar,
        "bio": bio,
        "score_total": 0,
        "classement": 0,
        "quiz_joues": 0,
        "precision": 0.0,
        "temps_reponse_moyen": 0.0,
        "points": 0,
        "glands": 0,
      });

      print("✅ [Firestore] Profil créé avec succès !");
    } catch (e) {
      print("⚠️ [Erreur Firestore - createProfile] $e");
    }
  }

  // 🔹 Récupère les infos du profil utilisateur
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      print("📡 [Firestore] Récupération du profil pour UID: $uid");

      var doc = await _db.collection('users').doc(uid).get();

      if (doc.exists) {
        print("✅ [Firestore] Profil récupéré : ${doc.data()}");
        return doc.data();
      } else {
        print("❌ [Firestore] Aucun profil trouvé !");
        return null;
      }
    } catch (e) {
      print("⚠️ [Erreur Firestore - getProfile] $e");
      return null;
    }
  }

  /// 🔹 Vérifie si un pseudo est déjà pris par un autre utilisateur.
  Future<bool> isPseudoTaken(String pseudo, {required String excludeUid}) async {
    try {
      final query = await _db
        .collection('users')
        .where('pseudo', isEqualTo: pseudo)
        .get();

      // S’il existe au moins un document dont l’ID est différent de excludeUid, le pseudo est pris
      return query.docs.any((doc) => doc.id != excludeUid);
    } catch (e) {
      print("⚠️ [Firestore - isPseudoTaken] $e");
      // En cas d’erreur, on considère le pseudo comme déjà pris pour éviter les conflits
      return true;
    }
  }
}