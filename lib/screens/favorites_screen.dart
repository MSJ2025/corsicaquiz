import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/favorite_service.dart';

class FavoritesScreen extends StatelessWidget {
  FavoritesScreen({Key? key}) : super(key: key);
  final FavoriteService _favoriteService = FavoriteService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes favoris')),
        body: const Center(child: Text('Utilisateur non connecté.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mes favoris')),
      body: StreamBuilder<List<String>>(
        stream: _favoriteService.favoritesStream(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final favIds = snapshot.data!;
          if (favIds.isEmpty) {
            return const Center(child: Text('Aucun favori.'));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: favIds)
                .snapshots(),
            builder: (context, usersSnapshot) {
              if (!usersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = usersSnapshot.data!.docs;
              if (users.isEmpty) {
                return const Center(child: Text('Aucun favori.'));
              }
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final data = users[index].data() as Map<String, dynamic>;
                  final pseudo = data['pseudo'] ?? 'Sans pseudo';
                  final avatar = data['avatar'] ?? '1.png';
                  final points = data['points'] ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          AssetImage('assets/images/avatars/$avatar'),
                    ),
                    title: Text(pseudo),
                    subtitle: Text('$points points'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
