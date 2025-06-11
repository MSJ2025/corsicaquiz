import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:corsicaquiz/main.dart'; // if you have navigatorKey defined there
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DuelQuestionService {
  Future<List<Map<String, dynamic>>> getBalancedQuestionsFromDomains(List<String> selectedDomains) async {
    List<Map<String, dynamic>> allQuestions = [];

    for (String domain in selectedDomains) {
      try {
        final jsonString = await rootBundle.loadString('assets/data/$domain.json');
        final List<dynamic> jsonList = json.decode(jsonString);
        final casted = jsonList.whereType<Map<String, dynamic>>().toList();
        allQuestions.addAll(casted);
      } catch (e) {
        debugPrint("❌ Erreur de chargement du domaine '$domain': $e");
      }
    }

    allQuestions = allQuestions.where((q) =>
      q.containsKey('question') &&
      q.containsKey('reponses') &&
      q['reponses'] is List &&
      (q['reponses'] as List).any((r) => r is Map && r['correct'] == true && r.containsKey('texte'))
    ).toList();

    final easy = allQuestions.where((q) => q['difficulte'] == 'Facile').toList()..shuffle();
    final medium = allQuestions.where((q) => q['difficulte'] == 'Moyen').toList()..shuffle();
    final hard = allQuestions.where((q) => q['difficulte'] == 'Difficile').toList()..shuffle();

    final selected = [
      ...easy.take(4),
      ...medium.take(4),
      ...hard.take(4),
    ]..shuffle();

    debugPrint("✅ ${selected.length} questions valides sélectionnées");
    return selected;
  }
}

