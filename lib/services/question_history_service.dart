import 'package:shared_preferences/shared_preferences.dart';

class QuestionHistoryService {
  static const String _storageKey = 'recent_questions';
  static const int maxEntries = 50;

  Future<List<String>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey) ?? [];
  }

  Future<void> addQuestion(String key) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_storageKey) ?? [];
    history.remove(key);
    history.add(key);
    if (history.length > maxEntries) {
      history = history.sublist(history.length - maxEntries);
    }
    await prefs.setStringList(_storageKey, history);
  }

  Future<bool> contains(String key) async {
    final history = await loadHistory();
    return history.contains(key);
  }
}
