import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteService {
  final FirebaseFirestore _db;

  FavoriteService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Stream<List<String>> favoritesStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc.id).toList());
  }

  Future<void> addFavorite(String uid, String favoriteUid) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(favoriteUid)
        .set({'uid': favoriteUid});
  }

  Future<void> removeFavorite(String uid, String favoriteUid) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(favoriteUid)
        .delete();
  }

}
