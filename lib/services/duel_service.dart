import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DuelService {
  final CollectionReference<Map<String, dynamic>> _duels =
      FirebaseFirestore.instance.collection('duels');

  Future<void> updateLastOpened(String duelId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _duels.doc(duelId).set({
      'lastOpened_$uid': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<int> totalUnreadDuels(String uid) {
    return _duels
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final Timestamp? updatedAt = data['updatedAt'];
        final Timestamp? lastOpened = data['lastOpened_$uid'];
        if (updatedAt != null &&
            (lastOpened == null || lastOpened.toDate().isBefore(updatedAt.toDate()))) {
          count++;
        }
      }
      return count;
    });
  }
}
