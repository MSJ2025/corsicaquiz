import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corsicaquiz/services/favorite_service.dart';

void main() {
  test('addFavorite et removeFavorite modifient les données', () async {
    final firestore = FakeFirebaseFirestore();
    final service = FavoriteService(firestore: firestore);

    await service.addFavorite('u1', 'fav');
    var snap = await firestore
        .collection('users')
        .doc('u1')
        .collection('favorites')
        .doc('fav')
        .get();
    expect(snap.exists, true);

    await service.removeFavorite('u1', 'fav');
    snap = await firestore
        .collection('users')
        .doc('u1')
        .collection('favorites')
        .doc('fav')
        .get();
    expect(snap.exists, false);
  });
}
