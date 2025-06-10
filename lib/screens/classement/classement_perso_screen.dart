import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClassementPersoScreen extends StatefulWidget {
  final String? userId;
  const ClassementPersoScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<ClassementPersoScreen> createState() => _ClassementPersoScreenState();
}

class _ClassementPersoScreenState extends State<ClassementPersoScreen> {
  Map<String, dynamic> userData = {};

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    final uid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final wins = await _loadWeeklyWins(uid);
      setState(() {
        userData = doc.data() ?? {};
        userData['pointsWins'] = wins['pointsWins'];
        userData['duelWins'] = wins['duelWins'];
      });
    }
  }

  Future<Map<String, int>> _loadWeeklyWins(String uid) async {
    final snapshot = await FirebaseFirestore.instance.collection('weekly_winners').get();
    int pointsWins = 0;
    int duelWins = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['top_points']?['uid'] == uid) pointsWins++;
      if (data['top_wins']?['uid'] == uid) duelWins++;
    }

    return {'pointsWins': pointsWins, 'duelWins': duelWins};
  }

  @override
  Widget build(BuildContext context) {
    final pseudo = userData['pseudo'] ?? 'Moi';
    final points = userData['points'] ?? 0;
    final glands = userData['glands'] ?? 0;
    final wins = userData['totalWins'] ?? 0;
    final losses = userData['totalLosses'] ?? 0;
    final totalDuels = wins + losses;
    final avatar = userData['avatar'] ?? '1.png';
    final successRate = totalDuels > 0 ? ((wins / totalDuels) * 100).toStringAsFixed(1) : "0";
    int starCount = 1;
    if (points >= 1000) starCount = 2;
    if (points >= 5000) starCount = 3;
    if (points >= 20000) starCount = 4;
    if (points >= 40000) starCount = 5;

    final pointsWins = userData['pointsWins'] ?? 0;
    final duelWins = userData['duelWins'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Statistiques Joueur'),
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
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: userData['online'] == true ? Colors.green.withOpacity(0.4) : Colors.blueGrey.withOpacity(0.9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                margin: const EdgeInsets.only(bottom: 1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: AssetImage('assets/images/avatars/$avatar'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pseudo,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(starCount, (index) => const Icon(Icons.star, color: Colors.yellow, size: 28)),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId ?? FirebaseAuth.instance.currentUser!.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();

                          final docData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                          final online = docData['online'] == true;

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: online ? Colors.greenAccent : Colors.orangeAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    if (online)
                                      BoxShadow(
                                        color: Colors.greenAccent.withOpacity(0.6),
                                        spreadRadius: 3,
                                        blurRadius: 6,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                online ? "Connecté" : "Hors ligne",
                                style: TextStyle(
                                  color: online ? Colors.greenAccent : Colors.orangeAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              _buildStatCard(Icons.star, 'Points Totaux', points.toString()),
              _buildStatCard(Icons.sports_kabaddi, 'Duels joués', totalDuels.toString()),
              _buildStatCard(Icons.check_circle, 'Victoires', wins.toString()),
              _buildStatCard(Icons.cancel, 'Défaites', losses.toString()),
              _buildStatCard(Icons.bar_chart, 'Taux de réussite', '$successRate %'),
              _buildStatCard(Icons.eco, 'Glands', glands.toString()),
              _buildStatCard(Icons.emoji_events, 'Victoires Hebdo (Points)', pointsWins.toString()),
              _buildStatCard(Icons.sports_martial_arts, 'Victoires Hebdo (Duels)', duelWins.toString()),
              const SizedBox(height: 3),

              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  icon: const Icon(Icons.leaderboard),
                  label: const Text('Voir les semaines gagnées'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Semaines gagnées'),
                        content: FutureBuilder(
                          future: FirebaseFirestore.instance.collection('weekly_winners').get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            final docs = snapshot.data!.docs;
                            final uid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
                            final pointsWeeks = docs.where((doc) =>
                              doc.data()['top_points']?['uid'] == uid).map((doc) => doc.id).toList();
                            final duelsWeeks = docs.where((doc) =>
                              doc.data()['top_wins']?['uid'] == uid).map((doc) => doc.id).toList();

                            return SizedBox(
                              height: 250,
                              width: 300,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("🏆 En Points :", style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  ...pointsWeeks.map((w) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.star, color: Colors.orange),
                                    title: Text("Semaine $w"),
                                  )),
                                  const SizedBox(height: 12),
                                  const Text("⚔️ En Duels :", style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  ...duelsWeeks.map((w) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.sports_martial_arts, color: Colors.deepPurple),
                                    title: Text("Semaine $w"),
                                  )),
                                ],
                              ),
                            );
                          },
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Fermer'),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      color: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.4),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
