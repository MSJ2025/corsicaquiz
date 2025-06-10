import 'package:cloud_firestore/cloud_firestore.dart';

class WinnerService {
  static Future<void> checkAndSaveLastWeekWinners() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 1)); // heure de Paris
    final lastWeek = now.subtract(const Duration(days: 7));
    final monday = lastWeek.subtract(Duration(days: lastWeek.weekday - 1));
    final weekNumber = ((monday.difference(DateTime(monday.year, 1, 1)).inDays) / 7).floor() + 1;
    final weekId = '${monday.year}-W$weekNumber';

    final winnersDoc = await FirebaseFirestore.instance.collection('weekly_winners').doc(weekId).get();
    if (winnersDoc.exists) {
      return; // Déjà enregistré
    }

    final leaderboardDoc = await FirebaseFirestore.instance.collection('weekly_leaderboard').doc(weekId).get();
    if (!leaderboardDoc.exists) return;

    final data = leaderboardDoc.data() ?? {};
    final List winsRanking = data['wins_ranking'] ?? [];
    final List pointsRanking = data['points_ranking'] ?? [];

    final topWins = winsRanking.isNotEmpty ? winsRanking.first : null;
    final topPoints = pointsRanking.isNotEmpty ? pointsRanking.first : null;

    if (topWins != null && topPoints != null) {
      await FirebaseFirestore.instance.collection('weekly_winners').doc(weekId).set({
        'top_wins': topWins,
        'top_points': topPoints,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }
}
