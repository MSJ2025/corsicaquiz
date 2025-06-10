import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'domain_selection_screen.dart';
import 'duel_game_screen.dart';

class DuelResultScreen extends StatefulWidget {
  final String duelId;
  const DuelResultScreen({Key? key, required this.duelId}) : super(key: key);

  @override
  _DuelResultScreenState createState() => _DuelResultScreenState();
}

class _DuelResultScreenState extends State<DuelResultScreen> {
  bool _visible = false;
  bool _statsUpdated = false;
  bool _isSendingRematch = false;
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _duelFuture;

  @override
  void initState() {
    super.initState();
    // Load duel data and record stats once
    _duelFuture = FirebaseFirestore.instance
      .collection('duels')
      .doc(widget.duelId)
      .get()
      .then((snapshot) async {
        await _recordStats(snapshot.data() as Map<String, dynamic>);
        return snapshot;
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _visible = true);
    });
  }

  Future<void> _recordStats(Map<String, dynamic> data) async {
    if (_statsUpdated) return;
    final player1 = data['player1'] as Map<String, dynamic>? ?? {};
    final player2 = data['player2'] as Map<String, dynamic>? ?? {};
    final score1 = player1['score'] ?? 0;
    final score2 = player2['score'] ?? 0;

    final winnerUid = score1 > score2 ? data['from'] as String : data['to'] as String;
    final myPseudo = FirebaseAuth.instance.currentUser!.uid == data['from']
      ? (player1['pseudo'] ?? 'Moi') as String
      : (player2['pseudo'] ?? 'Moi') as String;
    final myScore = FirebaseAuth.instance.currentUser!.uid == data['from'] ? score1 : score2;

    // 1) Increment totalWins in user profile
    await FirebaseFirestore.instance
      .collection('users')
      .doc(winnerUid)
      .update({'totalWins': FieldValue.increment(1)});

    // 1bis) Increment general leaderboard wins count
    await FirebaseFirestore.instance
      .collection('leaderboard')
      .doc(winnerUid)
      .set({
        'wins': FieldValue.increment(1),
        'pseudo': myPseudo,
      }, SetOptions(merge: true));

    // 2) Add to weekly leaderboard
    final now = DateTime.now().toUtc().add(const Duration(hours: 1));
    final lastWeek = now.subtract(const Duration(days: 7));
    final monday = lastWeek.subtract(Duration(days: lastWeek.weekday - 1));
    final weekNumber = ((monday.difference(DateTime(monday.year, 1, 1)).inDays) / 7).floor() + 1;
    final weekId = '${monday.year}-W$weekNumber';

    await FirebaseFirestore.instance
      .collection('weekly_leaderboard')
      .doc(weekId)
      .set({
        'wins_ranking': FieldValue.arrayUnion([
          {'uid': winnerUid, 'pseudo': myPseudo, 'wins': 1}
        ]),
        'points_ranking': FieldValue.arrayUnion([
          {'uid': winnerUid, 'pseudo': myPseudo, 'points': myScore}
        ]),
      }, SetOptions(merge: true));

    _statsUpdated = true;
  }

  Future<void> _sendRematchRequest(String opponentId, String opponentPseudo) async {
    if (_isSendingRematch) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isSendingRematch = true;
    });

    final selectedDomains = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DomainSelectionScreen(),
      ),
    );

    if (selectedDomains == null || selectedDomains.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez choisir exactement 6 domaines.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSendingRematch = false;
      });
      return;
    }

    final myId = currentUser.uid;
    final mySnapshot = await FirebaseFirestore.instance.collection('users').doc(myId).get();
    final myPseudo = mySnapshot.data()?['pseudo'] ?? 'Joueur';

    List<Map<String, dynamic>> allQuestions = [];

    Future<List<dynamic>> loadJson(String path) async {
      final String jsonString = await rootBundle.loadString(path);
      return json.decode(jsonString);
    }

    final difficultyMap = {
      'Facile': 4,
      'Moyen': 4,
      'Difficile': 4,
    };

    for (final difficulty in difficultyMap.keys) {
      final filteredDomains = List<String>.from(selectedDomains);
      filteredDomains.shuffle();

      for (final domain in filteredDomains) {
        if (allQuestions.where((q) => q['difficulte'] == difficulty).length >= difficultyMap[difficulty]!) break;

        final questions = await loadJson('assets/data/$domain.json');
        final filtered = (questions as List).where((q) => q['difficulte'] == difficulty).toList();
        filtered.shuffle();
        if (filtered.isNotEmpty) {
          allQuestions.add(filtered.first);
        }
      }
    }

    final duelData = {
      'from': myId,
      'to': opponentId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'questions': allQuestions,
      'domainesEnvoyeur': selectedDomains,
      'player1': {
        'uid': myId,
        'pseudo': myPseudo,
        'score': 0,
        'currentIndex': 0,
      },
      'player2': {
        'uid': opponentId,
        'pseudo': opponentPseudo,
        'score': 0,
        'currentIndex': 0,
      },
      'participants': [myId, opponentId],
    };

    final duelRef = await FirebaseFirestore.instance.collection('duels').add(duelData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nouveau duel créé !'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      _isSendingRematch = false;
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DuelGameScreen(duelId: duelRef.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Résultat du Duel'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.blueGrey],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _duelFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.data() == null) {
                  return const Center(child: Text('Données du duel introuvables.'));
                }

                final data = snapshot.data!.data()!;
                final questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
                final player1 = data['player1'] as Map<String, dynamic>? ?? {};
                final player2 = data['player2'] as Map<String, dynamic>? ?? {};
                final score1 = player1['score'] ?? 0;
                final score2 = player2['score'] ?? 0;
                final isCurrentPlayer1 = FirebaseAuth.instance.currentUser!.uid == data['from'];
                final myScore = isCurrentPlayer1 ? score1 : score2;
                final opponentScore = isCurrentPlayer1 ? score2 : score1;
                final myPseudo = isCurrentPlayer1 ? player1['pseudo'] ?? 'Moi' : player2['pseudo'] ?? 'Moi';
                final opponentPseudo = isCurrentPlayer1 ? player2['pseudo'] ?? 'Adversaire' : player1['pseudo'] ?? 'Adversaire';

                String resultText;
                IconData resultIcon;
                Color resultColor;

                if (score1 == score2) {
                  resultText = 'Égalité !';
                  resultIcon = Icons.balance;
                  resultColor = Colors.amber;
                } else if ((isCurrentPlayer1 && score1 > score2) || (!isCurrentPlayer1 && score2 > score1)) {
                  resultText = 'Tu as gagné ! 🎉';
                  resultIcon = Icons.emoji_events;
                  resultColor = Colors.green;
                } else {
                  resultText = 'Tu as perdu 😢';
                  resultIcon = Icons.sentiment_dissatisfied;
                  resultColor = Colors.red;
                }

                final answers1 = player1['answers'] as Map<String, dynamic>? ?? {};
                final answers2 = player2['answers'] as Map<String, dynamic>? ?? {};

                return Column(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 800),
                      opacity: _visible ? 1.0 : 0.0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [resultColor, resultColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(resultIcon, color: Colors.white, size: 72),
                            const SizedBox(height: 12),
                            Text(
                              resultText,
                              style: GoogleFonts.poppins(
                                  fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$myPseudo vs $opponentPseudo',
                              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$myScore - $opponentScore',
                              style: GoogleFonts.poppins(
                                  fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ListView.separated(
                            itemCount: questions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final q = questions[index];
                              final a1 = answers1['$index'] ?? '—';
                              final a2 = answers2['$index'] ?? '—';
                              final correct = q['answer'];
                              final tileColor = a1 == correct ? Colors.green : Colors.red;
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [tileColor.withOpacity(0.7), tileColor.withOpacity(0.3)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  backgroundColor: Colors.transparent,
                                  collapsedBackgroundColor: Colors.transparent,
                                  title: Text(
                                    "Q${index + 1}: ${q['text']}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  iconColor: Colors.white,
                                  collapsedIconColor: Colors.white,
                                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: a1 == correct ? Colors.green : Colors.red),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  "Toi",
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    color: a1 == correct ? Colors.green : Colors.red,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  a1,
                                                  style: GoogleFonts.poppins(
                                                    color: a1 == correct ? Colors.green : Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: a2 == correct ? Colors.green : Colors.red),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  opponentPseudo,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    color: a2 == correct ? Colors.green : Colors.red,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  a2,
                                                  style: GoogleFonts.poppins(
                                                    color: a2 == correct ? Colors.green : Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final opponentId = isCurrentPlayer1 ? data['to'] as String : data['from'] as String;
                                final opponentPseudo = isCurrentPlayer1 ? (player2['pseudo'] ?? 'Adversaire') : (player1['pseudo'] ?? 'Adversaire');
                                _sendRematchRequest(opponentId, opponentPseudo);
                              },
                              icon: const Icon(Icons.casino),
                              label: const Text('Revanche'),
                              style: ElevatedButton.styleFrom(
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                backgroundColor: Colors.orangeAccent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                              icon: const Icon(Icons.home),
                              label: const Text('Retour à l\'accueil'),
                              style: ElevatedButton.styleFrom(
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                backgroundColor: Colors.yellow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
