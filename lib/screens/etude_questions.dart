import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EtudeQuestionsScreen extends StatefulWidget {
  const EtudeQuestionsScreen({Key? key}) : super(key: key);

  @override
  _EtudeQuestionsScreenState createState() => _EtudeQuestionsScreenState();
}

class _EtudeQuestionsScreenState extends State<EtudeQuestionsScreen> {
  List<Map<String, dynamic>> allQuestions = [];

  @override
  void initState() {
    super.initState();
    loadAllQuestions();
  }

  Future<void> loadAllQuestions() async {
    final sources = [
      'assets/data/questions_culture.json',
      'assets/data/questions_faune_flore.json',
      'assets/data/questions_histoire.json',
      'assets/data/questions_personnalites.json',
    ];

    List<Map<String, dynamic>> all = [];

    for (String path in sources) {
      String jsonString = await rootBundle.loadString(path);
      final data = json.decode(jsonString);
      if (data is List) {
        all.addAll(data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)));
      }
    }

    setState(() {
      allQuestions = all;
    });
  }

  void signalerProbleme(Map<String, dynamic> question) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text("Signaler un problème"),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "Décrivez le problème rencontré avec cette question",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final message = controller.text.trim();
                if (message.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('signalements_questions')
                      .add({
                    'timestamp': Timestamp.now(),
                    'question': question['question'],
                    'categorie': question['categorie'],
                    'explication': question['explication'],
                    'reponses': question['reponses'],
                    'message': message,
                  });
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Merci ! Le problème a été signalé."),
                ));
              },
              child: const Text("Envoyer"),
            ),
          ],
        );
      },
    );
  }

  Widget buildCategoryView(String categoryKeyword) {
    final filteredQuestions = allQuestions.where((q) {
      final cat = q['categorie']?.toString().toLowerCase() ?? '';
      return cat.contains(categoryKeyword.toLowerCase());
    }).toList();

    final questionCount = filteredQuestions.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '$questionCount question(s)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: filteredQuestions.length,
            itemBuilder: (context, index) {
              final q = filteredQuestions[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  title: Text(q["question"] ?? "",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(q["categorie"] ?? ""),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          ...((q["reponses"] as List).map((rep) {
                            final r = rep as Map<String, dynamic>;
                            return ListTile(
                              leading: Icon(
                                r["correct"] == true
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: r["correct"] == true ? Colors.green : null,
                              ),
                              title: Text(r["texte"] ?? ""),
                            );
                          })),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Explication : ${q["explication"] ?? ""}",
                              style: const TextStyle(
                                  fontStyle: FontStyle.italic, color: Colors.black87),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => signalerProbleme(q),
                              icon: const Icon(Icons.report_problem_outlined),
                              label: const Text("Signaler un problème"),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'Culture',
      'Faune et flore',
      'Histoire',
      'Personnalités',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Étude des Questions"),
      ),
      body: allQuestions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Container(
                    color: Colors.orangeAccent,
                    child: TabBar(
                      isScrollable: true,
                      indicatorColor: Colors.white,
                      tabs: categories.map((category) {
                        final count = allQuestions.where((q) {
                          final cat = q['categorie']?.toString().toLowerCase() ?? '';
                          return cat.contains(category.toLowerCase());
                        }).length;
                        return Tab(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(category),
                              Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: categories.map(buildCategoryView).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
