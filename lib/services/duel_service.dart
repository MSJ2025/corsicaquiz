// Service pour créer un duel entre deux joueurs
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/duel_screens/domain_selection_screen.dart';
import 'duel_question_service.dart';

class DuelService {
  Future<String?> sendDuelRequest({
    required BuildContext context,
    required String opponentId,
    required String opponentPseudo,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final selectedDomains = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DomainSelectionScreen()),
    );

    if (selectedDomains == null || selectedDomains.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez choisir exactement 6 domaines.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    final myId = currentUser.uid;
    final mySnapshot =
        await FirebaseFirestore.instance.collection('users').doc(myId).get();
    final myPseudo = mySnapshot.data()?['pseudo'] ?? 'Joueur';

    final questions = await DuelQuestionService()
        .getBalancedQuestionsFromDomains(List<String>.from(selectedDomains));

    final duelData = {
      'from': myId,
      'to': opponentId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'questions': questions,
      'domainesEnvoyeur': selectedDomains,
      'player1': {
        'uid': myId,
        'pseudo': myPseudo,
        'score': 0,
        'currentIndex': 0,
      },
      'player2': {
        'uid': opponentId,
        'pseudo': opponentPseudo,
        'score': 0,
        'currentIndex': 0,
      },
      'participants': [myId, opponentId],
    };

    final duelRef =
        await FirebaseFirestore.instance.collection('duels').add(duelData);
    return duelRef.id;
  }
}
