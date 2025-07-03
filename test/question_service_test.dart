import 'package:flutter_test/flutter_test.dart';
import 'package:corsicaquiz/services/question_service.dart';

class FakeQuestionService extends QuestionService {
  @override
  Future<List<Map<String, dynamic>>> loadQuestions() async {
    return [
      {'difficulte': 'facile'},
      {'difficulte': 'facile'},
      {'difficulte': 'facile'},
      {'difficulte': 'facile'},
      {'difficulte': 'moyen'},
      {'difficulte': 'moyen'},
      {'difficulte': 'moyen'},
      {'difficulte': 'moyen'},
      {'difficulte': 'difficile'},
      {'difficulte': 'difficile'},
      {'difficulte': 'difficile'},
      {'difficulte': 'difficile'},
    ];
  }
}

void main() {
  test('getBalancedQuestions renvoie un ensemble équilibré', () async {
    final service = FakeQuestionService();
    final questions = await service.getBalancedQuestions();
    expect(questions.length, 9);

    final counts = {'facile': 0, 'moyen': 0, 'difficile': 0};
    for (var q in questions) {
      counts[q['difficulte']] = counts[q['difficulte']]! + 1;
    }

    expect(counts['facile'], 4);
    expect(counts['moyen'], 4);
    expect(counts['difficile'], 4);
  });
}
