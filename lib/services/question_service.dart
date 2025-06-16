import 'dart:convert';
import 'package:flutter/services.dart';

class QuestionService {
  Future<List<Map<String, dynamic>>> loadQuestions() async {
    final String response = await rootBundle.loadString('assets/data/questions_histoire.json');
    final List<dynamic> data = json.decode(response);

    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getBalancedQuestions() async {
    List<Map<String, dynamic>> allQuestions = await loadQuestions();

    // Séparer les questions par difficulté
    List<Map<String, dynamic>> easy = [];
    List<Map<String, dynamic>> medium = [];
    List<Map<String, dynamic>> hard = [];

    for (var q in allQuestions) {
      switch (q['difficulte']) {
        case 'facile':
          easy.add(q);
          break;
        case 'moyen':
          medium.add(q);
          break;
        case 'difficile':
          hard.add(q);
          break;
      }
    }

    // Mélanger chaque liste pour un ordre aléatoire
    easy.shuffle();
    medium.shuffle();
    hard.shuffle();

    // Sélectionner un mélange équilibré
    List<Map<String, dynamic>> selectedQuestions = [
      ...easy.take(3),
      ...medium.take(3),
      ...hard.take(3),
    ];

    // Mélanger toutes les questions sélectionnées
    selectedQuestions.shuffle();

    return selectedQuestions;
  }
}
