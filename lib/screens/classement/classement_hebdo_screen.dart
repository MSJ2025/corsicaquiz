import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'classement_perso_screen.dart';

class ClassementHebdoScreen extends StatefulWidget {
  const ClassementHebdoScreen({Key? key}) : super(key: key);

  @override
  State<ClassementHebdoScreen> createState() => _ClassementHebdoScreenState();
}

class _ClassementHebdoScreenState extends State<ClassementHebdoScreen> {
  String _currentWeekId = '';
  final ScrollController _scrollController = ScrollController();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _currentWeekId = _generateWeekId(DateTime.now().toUtc().add(Duration(hours: 1)));
  }

  String _generateWeekId(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final weekNumber = ((monday.difference(DateTime(monday.year, 1, 1)).inDays) / 7).floor() + 1;
    return '${monday.year}-W$weekNumber';
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchWeekData() {
    return FirebaseFirestore.instance.collection('weekly_leaderboard').doc(_currentWeekId).get();
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _fetchPastWeeks() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('weekly_leaderboard')
        .orderBy('end', descending: true)
        .get();
    return snapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          elevation: 0,
          title: const Text('Classement Hebdomadaire'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Victoires'),
              Tab(text: 'Points'),
            ],
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/paysage.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _fetchWeekData(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!.data() ?? {};
                  final List winsRanking = data['wins_ranking'] ?? [];
                  final List pointsRanking = data['points_ranking'] ?? [];

                  return TabBarView(
                    children: [
                      _buildRankingList(winsRanking, 'wins'),
                      _buildRankingList(pointsRanking, 'points'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        bottomSheet: FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
          future: _fetchPastWeeks(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final pastWeeks = snapshot.data!;
            return AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: _isExpanded ? MediaQuery.of(context).size.height * 0.5 : 60,
              child: SingleChildScrollView(
                child: Container(
                  color: Colors.blue,
                  child: ExpansionTile(
                    onExpansionChanged: (expanded) {
                      setState(() => _isExpanded = expanded);
                    },
                    collapsedBackgroundColor: Colors.blue,
                    backgroundColor: Colors.blue,
                    textColor: Colors.white,
                    iconColor: Colors.white,
                    collapsedTextColor: Colors.white,
                    collapsedIconColor: Colors.white,
                    title: const Text("Anciens classements"),
                    children: pastWeeks.map((doc) {
                      final data = doc.data() ?? {};
                      final weekId = doc.id;
                      final pointsRanking = (data['points_ranking'] ?? []) as List;
                      final winsRanking = (data['wins_ranking'] ?? []) as List;

                      // Regrouper les scores par utilisateur pour points
                      final Map<String, Map<String, dynamic>> aggregatedPoints = {};
                      for (var entry in pointsRanking) {
                        final uid = entry['uid'];
                        if (uid == null) continue;
                        if (!aggregatedPoints.containsKey(uid)) {
                          aggregatedPoints[uid] = Map<String, dynamic>.from(entry);
                        } else {
                          aggregatedPoints[uid]!['points'] =
                              (aggregatedPoints[uid]!['points'] ?? 0) + (entry['points'] ?? 0);
                        }
                      }
                      final List aggregatedPointsList = aggregatedPoints.values.toList();
                      aggregatedPointsList.sort((a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0));

                      // Regrouper les scores par utilisateur pour wins
                      final Map<String, Map<String, dynamic>> aggregatedWins = {};
                      for (var entry in winsRanking) {
                        final uid = entry['uid'];
                        if (uid == null) continue;
                        if (!aggregatedWins.containsKey(uid)) {
                          aggregatedWins[uid] = Map<String, dynamic>.from(entry);
                        } else {
                          aggregatedWins[uid]!['wins'] =
                              (aggregatedWins[uid]!['wins'] ?? 0) + (entry['wins'] ?? 0);
                        }
                      }
                      final List aggregatedWinsList = aggregatedWins.values.toList();
                      aggregatedWinsList.sort((a, b) => (b['wins'] ?? 0).compareTo(a['wins'] ?? 0));

                      final parts = weekId.split('-W');
                      final formattedWeekId = '${parts[0]} - semaine ${parts[1]}';

                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          elevation: 2,
                          child: ExpansionTile(
                            title: Text(formattedWeekId),
                            subtitle: const Text("Top 10 - Victoires et Points"),
                            children: [
                              SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("🏆 Victoires"),
                                      ...aggregatedWinsList.take(10).map((u) => ListTile(
                                        title: Text(
                                          u['pseudo'] ?? 'Anonyme',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        trailing: Text("${u['wins'] ?? 0} victoires"),
                                      )),
                                      const SizedBox(height: 10),
                                      const Text("📊 Points"),
                                      ...aggregatedPointsList.take(10).map((u) => ListTile(
                                        title: Text(
                                          u['pseudo'] ?? 'Anonyme',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        trailing: Text("${u['points'] ?? 0} points"),
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRankingList(List ranking, String keyLabel) {
    if (ranking.isEmpty) {
      return const Center(child: Text("Aucune donnée pour cette semaine."));
    }

    // Regrouper les scores par utilisateur
    final Map<String, Map<String, dynamic>> userMap = {};

    for (var entry in ranking) {
      final uid = entry['uid'];
      if (uid == null) continue;

      if (!userMap.containsKey(uid)) {
        userMap[uid] = Map<String, dynamic>.from(entry);
      } else {
        userMap[uid]![keyLabel] = (userMap[uid]![keyLabel] ?? 0) + (entry[keyLabel] ?? 0);
      }
    }

    final aggregatedRanking = userMap.values.toList();

    aggregatedRanking.sort((a, b) => (b[keyLabel] ?? 0).compareTo(a[keyLabel] ?? 0));

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final index = aggregatedRanking.indexWhere((u) => u['uid'] == currentUserId);
    if (index != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            index * 78.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: aggregatedRanking.length,
            itemBuilder: (context, index) {
              final user = aggregatedRanking[index];
              final uid = user['uid'] ?? '';
              String avatar = '1.png';
              FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
                if (doc.exists && doc.data() != null) {
                  final data = doc.data()!;
                  setState(() {
                    user['avatar'] = data['avatar'] ?? '1.png';
                  });
                }
              });
              avatar = user['avatar'] ?? '1.png';
              final isCurrentUser = user['uid'] == currentUserId;
              return Card(
                color: isCurrentUser ? Colors.green.withOpacity(0.8) : Colors.blue.shade600.withOpacity(0.5),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClassementPersoScreen(userId: uid),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          backgroundImage: AssetImage('assets/images/avatars/$avatar'),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    user['pseudo'] ?? 'Inconnu',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: Text(
                    "${user[keyLabel] ?? 0}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
