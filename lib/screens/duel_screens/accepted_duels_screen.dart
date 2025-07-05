import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:corsicaquiz/screens/duel_screens/duel_game_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AcceptedDuelsScreen extends StatelessWidget {
  final String currentUserId;

  const AcceptedDuelsScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Duels acceptés")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('duels')
            .where('status', isEqualTo: 'accepted')
            .where('participants', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Erreur de chargement"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final duels = snapshot.data!.docs;

          if (duels.isEmpty) {
            return const Center(child: Text("Aucun duel à jouer"));
          }

          return ListView.builder(
            itemCount: duels.length,
            itemBuilder: (context, index) {
              final duel = duels[index];
              final data = duel.data() as Map<String, dynamic>;
              final opponentPseudo = data['participantsInfo']?[currentUserId == data['user1'] ? 'user2Pseudo' : 'user1Pseudo'] ?? 'Adversaire';

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text("Duel contre $opponentPseudo"),
                  subtitle: const Text("Prêt à jouer"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DuelGameScreen(duelId: duel.id),
                        ),
                      );
                    },
                    child: const Text("Jouer"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
