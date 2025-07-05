import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corsicaquiz/services/duel_question_service.dart';

class FakeBundle extends CachingAssetBundle {
  final Map<String, String> data;
  FakeBundle(this.data);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (!data.containsKey(key)) {
      throw FlutterError('Asset $key not found');
    }
    return data[key]!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleQuestions = [
    {
      'question': 'Q1',
      'reponses': [ {'texte': 'A', 'correct': true} ],
      'difficulte': 'Facile'
    },
    {
      'question': 'Q2',
      'reponses': [ {'texte': 'A', 'correct': true} ],
      'difficulte': 'Facile'
    },
    {
      'question': 'Q3',
      'reponses': [ {'texte': 'A', 'correct': true} ],
      'difficulte': 'Moyen'
    },
    {
      'question': 'Q4',
      'reponses': [ {'texte': 'A', 'correct': true} ],
      'difficulte': 'Moyen'
    },
    {
      'question': 'Q5',
      'reponses': [ {'texte': 'A', 'correct': true} ],
      'difficulte': 'Difficile'
    },
    {
      'question': 'Q6',
      'reponses': [ {'texte': 'A', 'correct': true} ],
      'difficulte': 'Difficile'
    }
  ];

  final jsonData = jsonEncode(sampleQuestions);
  final bundle = FakeBundle({
    'assets/data/domain1.json': jsonData,
    'assets/data/domain2.json': jsonData,
  });

  test('getBalancedQuestionsFromDomains returns 12 balanced questions', () async {
    final service = DuelQuestionService(bundle: bundle);
    final questions = await service.getBalancedQuestionsFromDomains(['domain1', 'domain2']);
    expect(questions.length, 12);

    final counts = {'Facile': 0, 'Moyen': 0, 'Difficile': 0};
    for (final q in questions) {
      counts[q['difficulte']] = counts[q['difficulte']]! + 1;
    }
    expect(counts['Facile'], 4);
    expect(counts['Moyen'], 4);
    expect(counts['Difficile'], 4);
  });
}
