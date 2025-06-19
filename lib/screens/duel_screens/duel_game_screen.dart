import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/duel_question_service.dart';
import '/services/duel_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/background_music_service.dart';

Map<String, dynamic> opponentAnswers = {};

class DuelGameScreen extends StatefulWidget {
  final String duelId;

  const DuelGameScreen({Key? key, required this.duelId}) : super(key: key);

  @override
  State<DuelGameScreen> createState() => _DuelGameScreenState();
}

class _DuelGameScreenState extends State<DuelGameScreen> with SingleTickerProviderStateMixin {  final currentUser = FirebaseAuth.instance.currentUser;
  int currentIndex = 0;
  bool isLoading = true;
  List<dynamic> questions = [];
  String? fromUid;
  String? toUid;
  String? selectedAnswer;
  String opponentAvatarFile = '1.png';
  bool hasAlreadyPlayed = false;
  final player = AudioPlayer();
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;


@override
void initState() {
  super.initState();
  BackgroundMusicService.instance.pause();
  DuelService().updateLastOpened(widget.duelId);

  _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  _shakeAnimation = Tween<double>(begin: 0, end: 10)
      .chain(CurveTween(curve: Curves.elasticIn))
      .animate(_shakeController);

  player.setLoopMode(LoopMode.one);
  _loadDuel();
}

  @override
  void dispose() {
    BackgroundMusicService.instance.resume();
    player.stop();
    player.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadDuel() async {
    final docRef = FirebaseFirestore.instance.collection('duels').doc(widget.duelId);
    final doc = await docRef.get();
    debugPrint("📄 Document récupéré pour le duel ${widget.duelId} : ${doc.exists}");

    if (!doc.exists) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    // Removed previous hasAlreadyPlayed assignment. It will be computed after mapping duelQuestions.

    final data = doc.data();
    debugPrint("📊 Données du duel : $data");
    if (data == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    List<dynamic> duelQuestionsRaw = data['questions'] ?? [];
    List<Map<String, dynamic>> duelQuestions = duelQuestionsRaw.map<Map<String, dynamic>>((q) {
      if (q.containsKey('text') && q.containsKey('options') && q.containsKey('answer')) {
        // Format déjà correct
        return q.cast<String, dynamic>();
      } else {
        try {
          final questionText = q['question'] ?? 'Question manquante';
          final reponses = (q['reponses'] as List?) ?? [];
          final options = reponses.map((r) => r['texte'] as String).toList();
          final correctAnswer = reponses.firstWhere((r) => r['correct'] == true, orElse: () => null)?['texte'];

          if (correctAnswer == null || options.isEmpty) {
            throw Exception('Invalid answer format');
          }

          return {
            'text': questionText,
            'options': options,
            'answer': correctAnswer,
          };
        } catch (e) {
          debugPrint('❌ Erreur lors du mapping d’une question existante Firestore : $e');
          return {
            'text': 'Question invalide',
            'options': ['Erreur'],
            'answer': 'Erreur',
          };
        }
      }
    }).toList();

    debugPrint("✅ Questions générées : $duelQuestions");
    debugPrint("🛠 Questions locales mappées : $duelQuestions");

    await docRef.update({
      'questions': duelQuestions,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (duelQuestions.isEmpty) {
      final localQuestions = await DuelQuestionService().getBalancedQuestionsFromDomains([]);
      duelQuestions = localQuestions.map((q) => {
        'text': q['question'],
        'options': (q['reponses'] as List).map((r) => r['texte'] as String).toList(),
        'answer': (q['reponses'] as List).firstWhere((r) => r['correct'] == true)['texte'],
      }).toList();

      await FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({
        'questions': duelQuestions,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    debugPrint("✅ Chargement terminé. ${duelQuestions.length} question(s) prêtes.");
    final userField = currentUser!.uid == doc.data()?['from'] ? 'player1' : 'player2';
    final userData = doc.data()?[userField] ?? {};
    final answers = (userData['answers'] as Map?) ?? {};
    final alreadyPlayed = answers.length >= duelQuestions.length;

    setState(() {
      questions = duelQuestions;
      isLoading = false;
      fromUid = data['from'];
      toUid = data['to'];
      final isPlayer1 = currentUser!.uid == data['from'];
      final opponentData = isPlayer1 ? data['player2'] ?? {} : data['player1'] ?? {};
      opponentAnswers = opponentData['answers'] ?? {};
      opponentAvatarFile = opponentData['avatar'] ?? '1.png';
      hasAlreadyPlayed = alreadyPlayed;
    });
  }

  Future<void> submitAnswer(String answer) async {
    setState(() {
      selectedAnswer = answer;
    });
    await Future.delayed(Duration(milliseconds: 500));

    final question = questions[currentIndex];
    final isCorrect = answer == question['answer'];
    if (!isCorrect) {
      _shakeController.forward(from: 0);
    }
    await player.setAsset(isCorrect
        ? 'assets/sons/quiz/correct.mp3'
        : 'assets/sons/quiz/false.mp3');
    await player.play();
    await Future.delayed(Duration(milliseconds: 500));

    final userField = currentUser!.uid == (await FirebaseFirestore.instance.collection('duels').doc(widget.duelId).get()).data()?['from']
        ? 'player1'
        : 'player2';

    await FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({
      '$userField.answers.$currentIndex': selectedAnswer,
      '$userField.currentIndex': currentIndex + 1,
      '$userField.score': FieldValue.increment(isCorrect ? 1 : 0),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({
      'finishedBy': FieldValue.arrayUnion([currentUser!.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await player.setAsset('assets/sons/quiz/woosh.mp3');
    await player.play();
    await Future.delayed(Duration(milliseconds: 300));

    setState(() {
      currentIndex++;
    });
  }

  Future<void> _updateVictoryStatsIfNeeded(Map<String, dynamic> data, int score1, int score2) async {
    if ((score1 != score2) && data['resultRecorded'] != true) {
      final winnerUid = ((data['from'] == currentUser!.uid && score1 > score2) ||
                        (data['to'] == currentUser!.uid && score2 > score1))
          ? currentUser!.uid
          : (data['from'] == currentUser!.uid ? data['to'] : data['from']);

      final opponentUid = winnerUid == data['from'] ? data['to'] : data['from'];

      final userDoc = FirebaseFirestore.instance.collection('users').doc(winnerUid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);
        final userData = snapshot.data() ?? {};
        final int totalWins = (userData['totalWins'] ?? 0) + 1;
        final Map<String, dynamic> opponentWins = Map<String, dynamic>.from(userData['winsByOpponent'] ?? {});
        opponentWins[opponentUid] = (opponentWins[opponentUid] ?? 0) + 1;

        transaction.update(userDoc, {
          'totalWins': totalWins,
          'winsByOpponent': opponentWins,
        });

        // Calcul de la semaine ISO (UTC +1 pour Paris hiver)
        final now = DateTime.now().toUtc().add(Duration(hours: 1));
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final weekId = "${monday.year}-W${(monday.difference(DateTime(monday.year, 1, 1)).inDays / 7).floor() + 1}";

        // Récupérer le pseudo du gagnant
        final winnerSnapshot = await FirebaseFirestore.instance.collection('users').doc(winnerUid).get();
        final winnerPseudo = winnerSnapshot.data()?['pseudo'] ?? 'Anonyme';

        // Mettre à jour le classement hebdomadaire des victoires
        final weeklyRef = FirebaseFirestore.instance.collection('weekly_leaderboard').doc(weekId);
        await weeklyRef.set({
          'start': Timestamp.fromDate(monday),
          'end': Timestamp.fromDate(monday.add(Duration(days: 6, hours: 23, minutes: 59))),
        }, SetOptions(merge: true));

        await weeklyRef.set({
          'wins_ranking': FieldValue.arrayUnion([
            {
              'uid': winnerUid,
              'pseudo': winnerPseudo,
              'wins': 1,
            }
          ])
        }, SetOptions(merge: true));

        final currentUserDoc = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
        transaction.set(currentUserDoc, {}, SetOptions(merge: true));
        transaction.update(currentUserDoc, {
          'totalDuels': FieldValue.increment(1),
        });

        final opponentDoc = FirebaseFirestore.instance.collection('users').doc(opponentUid);
        transaction.set(opponentDoc, {}, SetOptions(merge: true));
        transaction.update(opponentDoc, {
          'totalDuels': FieldValue.increment(1),
          if (opponentUid != winnerUid) 'totalLosses': FieldValue.increment(1),
        });

        if ((data['player1']?['currentIndex'] ?? 0) >= (data['questions']?.length ?? 0) &&
            (data['player2']?['currentIndex'] ?? 0) >= (data['questions']?.length ?? 0)) {
          transaction.update(FirebaseFirestore.instance.collection('duels').doc(widget.duelId), {
            'isCompleted': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(FirebaseFirestore.instance.collection('duels').doc(widget.duelId), {
          'resultRecorded': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (currentIndex >= questions.length) {
      if (hasAlreadyPlayed == true) {
        return Scaffold(
          backgroundColor: const Color(0xFF1B1B2F),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, color: Colors.white, size: 64),
                  const SizedBox(height: 20),
                  const Text(
                    'Tu as déjà joué ce duel.',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Retour"),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('duels').doc(widget.duelId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final player1 = data['player1'] ?? {};
          final player2 = data['player2'] ?? {};
          final score1 = player1['score'] ?? 0;
          final score2 = player2['score'] ?? 0;
          final current1 = player1['currentIndex'] ?? 0;
          final current2 = player2['currentIndex'] ?? 0;

          final questionsLength = questions.length;

          final bothFinished = current1 >= questionsLength && current2 >= questionsLength;
          final opponentUid = data['from'] == currentUser!.uid ? data['to'] as String : data['from'] as String;
          final opponentFuture = FirebaseFirestore.instance.collection('users').doc(opponentUid).get();

          if (!bothFinished) {
            return Scaffold(
              backgroundColor: const Color(0xFF1B1B2F),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty, color: Colors.amberAccent, size: 80),
                      const SizedBox(height: 20),
                      const Text(
                        'En attente de ton adversaire...',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tu as terminé toutes les questions.\nLaisse à ton adversaire un peu de temps pour terminer à son tour.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text(
                          "Quitter",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          String resultText;
          if (score1 == score2) {
            resultText = 'Égalité !';
          } else if ((data['from'] == currentUser!.uid && score1 > score2) ||
                     (data['to'] == currentUser!.uid && score2 > score1)) {
            resultText = 'Tu as gagné !';
          } else {
            resultText = 'Tu as perdu';
          }

          final answers1 = player1['answers'] as Map<String, dynamic>? ?? {};
          final answers2 = player2['answers'] as Map<String, dynamic>? ?? {};

          final comparisonWidgets = List.generate(questions.length, (index) {
            final q = questions[index];
            final a1 = answers1['$index'] ?? '—';
            final a2 = answers2['$index'] ?? '—';
            final correct = q['answer'];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Q${index + 1}: ${q['text']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("• Toi : $a1 ${a1 == correct ? '✅' : '❌'}"),
                Text("• Adversaire : $a2 ${a2 == correct ? '✅' : '❌'}"),
                const SizedBox(height: 12),
              ],
            );
          });

          _updateVictoryStatsIfNeeded(data, score1, score2);

          return Scaffold(
            appBar: AppBar(
              title: const Text('Résultat du Duel'),
              backgroundColor: Colors.blue,
              centerTitle: true,
              elevation: 0,
            ),
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.yellow, Colors.orangeAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              resultText,
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Inline logic for player scores
                            Builder(
                              builder: (context) {
                                final isPlayer1 = data['from'] == currentUser!.uid;
                                final userScore = isPlayer1 ? score1 : score2;
                                final opponentScore = isPlayer1 ? score2 : score1;
                                return Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        // Player score card
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Colors.blue, Colors.blueAccent],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            children: [
                                              const Icon(Icons.person, color: Colors.white, size: 28),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Ton score',
                                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$userScore / ${questions.length}',
                                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Opponent score card
                                        FutureBuilder<DocumentSnapshot>(
                                          future: opponentFuture,
                                          builder: (ctx, snapOpp) {
                                            final pseudo = (snapOpp.hasData && snapOpp.data!.exists)
                                                ? (snapOpp.data!.data() as Map<String, dynamic>)['pseudo'] ?? 'Adversaire'
                                                : '...';
                                            return Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Colors.blueGrey, Colors.blueAccent],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                children: [
                                                  const Icon(Icons.person_outline, color: Colors.white, size: 28),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    pseudo,
                                                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '$opponentScore / ${questions.length}',
                                                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Expandable question cards
                      ...List.generate(questions.length, (index) {
                        final q = questions[index];
                        final answers1 = player1['answers'] as Map<String, dynamic>? ?? {};
                        final answers2 = player2['answers'] as Map<String, dynamic>? ?? {};
                        final isPlayer1 = data['from'] == currentUser!.uid;
                        final aUser = isPlayer1 ? (answers1['$index'] ?? '—') : (answers2['$index'] ?? '—');
                        final aOpp = isPlayer1 ? (answers2['$index'] ?? '—') : (answers1['$index'] ?? '—');
                        final correct = q['answer'];
                        final isCorrect = aUser == correct;
                        final primaryColor = isCorrect ? Colors.green : Colors.red;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(0.7),
                                primaryColor.withOpacity(0.3)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            backgroundColor: Colors.transparent,
                            collapsedBackgroundColor: Colors.transparent,
                            title: Text(
                              "Q${index + 1}: ${q['text']}",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            iconColor: Colors.white,
                            collapsedIconColor: Colors.white,
                            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.black, Colors.blueGrey.withOpacity(0.7)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  title: Text(
                                    'Toi: $aUser',
                                    style: GoogleFonts.acme(
                                      color: isCorrect ? Colors.greenAccent : Colors.redAccent,

                                    ),
                                  ),
                                ),
                              ),
                              FutureBuilder<DocumentSnapshot>(
                                future: opponentFuture,
                                builder: (ctx, snapOpp) {
                                  final pseudo = (snapOpp.hasData && snapOpp.data!.exists)
                                      ? (snapOpp.data!.data() as Map<String, dynamic>)['pseudo'] ?? 'Adversaire'
                                      : '...';
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.black, Colors.blueGrey.withOpacity(0.7)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        '$pseudo: $aOpp',
                                        style: GoogleFonts.acme(
                                          color: aOpp == correct ? Colors.greenAccent : Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    final question = questions[currentIndex];
    final questionText = question['text'] ?? 'Question indisponible';
    final options = List<String>.from(question['options'] ?? []);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B1B2F), Color(0xFF162447)],
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            // Avatars et scores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: AssetImage('assets/images/avatars/1.png'),
                          ),
                          const SizedBox(height: 6),
                          const Text('Toi', style: TextStyle(color: Colors.white)),
                        ],
                      );
                    }
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final pseudo = data['pseudo'] ?? 'Moi';
                    final avatar = data['avatar'] ?? '1.png';
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: AssetImage('assets/images/avatars/$avatar'),
                        ),
                        const SizedBox(height: 6),
                        Text(pseudo, style: TextStyle(color: Colors.white)),
                      ],
                    );
                  },
                ),
                Column(
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.white.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 100,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 0.0,
                                  end: (currentIndex + 1) / questions.length,
                                ),
                                duration: Duration(milliseconds: 500),
                                builder: (context, value, child) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: Colors.white24,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                    minHeight: 6,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${currentIndex + 1}/${questions.length}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    if (fromUid == null || toUid == null) {
                      return Column(
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text("Chargement de l'adversaire...", style: TextStyle(color: Colors.white)),
                        ],
                      );
                    }
                    final opponentUid = currentUser!.uid == fromUid ? toUid! : fromUid!;
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(opponentUid)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: AssetImage('assets/images/avatars/1.png'),
                              ),
                              const SizedBox(height: 6),
                              const Text('...', style: TextStyle(color: Colors.white)),
                            ],
                          );
                        }
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        final pseudo = data['pseudo'] ?? 'Adversaire';
                        final avatar = data['avatar'] ?? '1.png';
                        return Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: AssetImage('assets/images/avatars/$avatar'),
                            ),
                            const SizedBox(height: 6),
                            Text(pseudo, style: TextStyle(color: Colors.white)),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Question
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                questionText,
                style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            // Réponses avec animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              child: Column(
                key: ValueKey(currentIndex),
                children: options.map((option) {
                  final isOpponentChoice = opponentAnswers['$currentIndex'] == option;
                  return Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: 1.0,
                        child: InkWell(
                          onTap: () => submitAnswer(option),
                          child: AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              final offset = selectedAnswer == option && selectedAnswer != question['answer']
                                  ? Offset(_shakeAnimation.value, 0)
                                  : Offset.zero;
                              return Transform.translate(
                                offset: offset,
                                child: child,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              decoration: BoxDecoration(
                                color: selectedAnswer == null
                                    ? Colors.white.withOpacity(0.07)
                                    : selectedAnswer == option
                                        ? (option == question['answer']
                                            ? Colors.green.withOpacity(0.8)
                                            : Colors.red.withOpacity(0.5))
                                        : Colors.white.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: const TextStyle(fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
