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

class OpponentDomainSelectionScreen extends StatefulWidget {
  final List<String> initialDomains;
  final String duelId;
  final Map<String, dynamic> duelData;

  const OpponentDomainSelectionScreen({
    Key? key,
    required this.initialDomains,
    required this.duelId,
    required this.duelData,
  }) : super(key: key);

  @override
  State<OpponentDomainSelectionScreen> createState() => _OpponentDomainSelectionScreenState();
}

class _OpponentDomainSelectionScreenState extends State<OpponentDomainSelectionScreen> {
  final List<String> availableDomains = [
    'questions_culture',
    'questions_faune_flore',
    'questions_histoire',
    'questions_personnalites',
  ];

  List<String> selectedDomains = [];

  @override
  void initState() {
    super.initState();
    selectedDomains = [];
  }

  void toggleDomain(String domain) {
    setState(() {
      if (selectedDomains.contains(domain)) {
        selectedDomains.remove(domain);
      } else {
        if (selectedDomains.length < 6) {
          selectedDomains.add(domain);
        }
      }
    });
  }

  void validateDomains() async {
    await FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({
      'status': 'accepted',
      'participants': [widget.duelData['from'], widget.duelData['to']],
      'domainesReceveur': selectedDomains,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Duel accepté avec sélection des domaines.")),
      );
      Navigator.pop(context, selectedDomains);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir 6 domaines'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Domaines sélectionnés : ${selectedDomains.length}/6',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: availableDomains.length,
              itemBuilder: (context, index) {
                final domain = availableDomains[index];
                final alreadySelectedBySender = widget.initialDomains.contains(domain);
                final isSelected = selectedDomains.contains(domain);
                return ListTile(
                  title: Text(domain),
                  trailing: alreadySelectedBySender
                      ? const Icon(Icons.lock, color: Colors.grey)
                      : Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? Colors.green : null,
                        ),
                  onTap: alreadySelectedBySender ? null : () => toggleDomain(domain),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: selectedDomains.length == 6 ? validateDomains : null,
              child: const Text('Valider les domaines'),
            ),
          )
        ],
      ),
    );
  }
}
