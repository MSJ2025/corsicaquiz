import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService {
  final _db = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _connSub;

  void init(String uid) {
    final statusRef    = _db.child('status/$uid');
    final connectedRef = _db.child('.info/connected');
    final offlineState = {
      'state': 'offline',
      'last_changed': ServerValue.timestamp
    };
    final onlineState = {
      'state': 'online',
      'last_changed': ServerValue.timestamp
    };

    _connSub = connectedRef.onValue.listen((event) {
      final connected = (event.snapshot.value as bool?) ?? false;
      if (connected) {
        // Dès qu’on se connecte au serveur RealtimeDB
        statusRef.onDisconnect().set(offlineState);
        statusRef.set(onlineState);
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'online': true});
      } else {
        // Perte de connexion détectée
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'online': false});
      }
    });
  }

  void dispose() {
    _connSub?.cancel();
  }
}