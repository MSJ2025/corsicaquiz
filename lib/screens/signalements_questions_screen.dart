import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SignalementsQuestionsScreen extends StatelessWidget {
  const SignalementsQuestionsScreen({Key? key}) : super(key: key);

  Future<void> supprimerSignalement(String id) async {
    await FirebaseFirestore.instance.collection('signalements_questions').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signalements de Questions'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('signalements_questions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erreur de chargement'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Aucun signalement enregistré.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final date = (data['timestamp'] as Timestamp?)?.toDate();
              final formattedDate = date != null ? DateFormat('dd/MM/yyyy – HH:mm').format(date) : 'Date inconnue';

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📅 $formattedDate', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('❓ Question : ${data['question']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('✅ Bonne réponse : ${data['bonne_reponse']}'),
                      const SizedBox(height: 4),
                      Text('🧠 Explication : ${data['explication']}'),
                      const SizedBox(height: 4),
                      Text('📂 Catégorie : ${data['categorie']}'),
                      const SizedBox(height: 4),
                      Text('🗣️ Message de l’utilisateur : ${data['message']}'),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirmer la suppression'),
                                content: const Text('Supprimer ce signalement ?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              supprimerSignalement(id);
                            }
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                        ),
                      )
                    ],
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
