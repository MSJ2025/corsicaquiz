import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class QuestionsSelectionScreen extends StatelessWidget {
  const QuestionsSelectionScreen({Key? key}) : super(key: key);

  final List<String> authorizedEmails = const [
    'pacman93@gmail.com',
    'alexandrejordan84@gmail.com',
    'dev.msj2025@gmail.com',
  ];

  bool _isAuthorized(User? user) {
    return user != null && authorizedEmails.contains(user.email);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (!_isAuthorized(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
        body: const Center(child: Text('Vous n\'êtes pas autorisé à consulter cette page.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Propositions de questions'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('propositions_questions')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erreur lors du chargement.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final questions = snapshot.data!.docs;

          if (questions.isEmpty) {
            return const Center(child: Text('Aucune proposition pour le moment.'));
          }

          return ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final data = questions[index].data() as Map<String, dynamic>;
              final cleanedData = Map<String, dynamic>.from(data);
              cleanedData['createdAt'] = (cleanedData['createdAt'] as Timestamp?)?.toDate().toIso8601String();
              final jsonString = const JsonEncoder.withIndent('  ').convert({
                "categorie": cleanedData["categorie"],
                "question": cleanedData["question"],
                "reponses": cleanedData["reponses"],
                "explication": cleanedData["explication"],
                "difficulte": cleanedData["difficulte"],
                "image": cleanedData["image"],
              });

              return Card(
                margin: const EdgeInsets.all(10),
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        jsonString,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.copy),
                            label: const Text('Copier'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: jsonString));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Contenu copié dans le presse-papier')),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.delete),
                            label: const Text('Supprimer'),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirmer la suppression'),
                                  content: const Text('Supprimer cette proposition ?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Annuler'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Supprimer'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await FirebaseFirestore.instance
                                    .collection('propositions_questions')
                                    .doc(questions[index].id)
                                    .delete();
                              }
                            },
                          ),
                        ],
                      ),
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
