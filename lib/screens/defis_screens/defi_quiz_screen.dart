import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour charger le JSON
import 'package:lottie/lottie.dart';
import 'package:flutter/gestures.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '/services/ad_service.dart';
import '/services/background_music_service.dart';


class HistoryQuizScreen extends StatefulWidget {
  @override
  _HistoryQuizScreenState createState() => _HistoryQuizScreenState();
}

class _HistoryQuizScreenState extends State<HistoryQuizScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _questions = [];
  String? _selectedCategory;
  int _score = 0;
  bool _answered = false;
  int _timeLeft = 60;
  Timer? _timer;
  bool _timerHighlight = false;
  String? _selectedDifficulty;
  Random _random = Random();
  Map<String, dynamic>? _currentQuestion;
  Set<String> _askedQuestions = {};
  Offset? _tapPosition;
  bool _showAnimation = false;
  String _animationAsset = 'assets/lottie/starexplose_facile.json';
  Offset? _scoreBubblePosition;
  int? _scoreGained;
  bool _showScoreBubble = false;
  late AnimationController _scoreBubbleController;
  late Animation<Offset> _scoreBubbleSlideAnimation;
  late Animation<double> _scoreBubbleScaleAnimation;
  late Animation<double> _scoreBubbleFadeAnimation;
  late AnimationController _scorePulseController;
  late Animation<double> _scorePulseAnimation;
  bool _showIntroCard = true;
  late AudioPlayer _audioPlayer;
  final AudioPlayer _correctSound = AudioPlayer();
  final AudioPlayer _wrongSound = AudioPlayer();
  final AudioPlayer _timerSound = AudioPlayer();
  final AudioPlayer _endSound = AudioPlayer();
  String _pseudo = "Inconnu";


  // Points et bonus temps
  Map<String, int> _difficultyPoints = {"Facile": 5, "Moyen": 10, "Difficile": 15};
  Map<String, int> _bonusTime = {"Facile": 1, "Moyen": 2, "Difficile": 3};

  @override
  void initState() {
    super.initState();
    BackgroundMusicService.instance.pause();
    FirebaseAnalytics.instance.logEvent(name: 'defi_quiz_started');
    _loadQuestions();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _timerSound.setReleaseMode(ReleaseMode.loop);
    _scorePulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _scorePulseAnimation = Tween<double>(begin: 1.0, end: 1.3)
      .chain(CurveTween(curve: Curves.easeOut))
      .animate(_scorePulseController);
    _scorePulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scorePulseController.reverse();
      }
    });
    _scorePulseController.repeat(period: Duration(seconds: 6));
    _scoreBubbleController = AnimationController(vsync: this, duration: Duration(milliseconds: 800));
    _scoreBubbleSlideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset(0, -1))
        .animate(CurvedAnimation(parent: _scoreBubbleController, curve: Curves.easeOut));
    _scoreBubbleScaleAnimation = Tween<double>(begin: 0.0, end: 1.5)
        .animate(CurvedAnimation(parent: _scoreBubbleController, curve: Curves.elasticOut));
    _scoreBubbleFadeAnimation = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _scoreBubbleController, curve: Curves.easeIn));
    _scoreBubbleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showScoreBubble = false;
        });
      }
    });
  }

  Future<void> _saveScoreToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final now = DateTime.now().toUtc().add(const Duration(hours: 1)); // Heure de Paris (UTC+1)

      // Calculer la semaine ISO
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekId = "${monday.year}-W${(monday.difference(DateTime(monday.year, 1, 1)).inDays / 7).floor() + 1}";

      // Récupérer pseudo utilisateur
      final userDoc = await userRef.get();
      _pseudo = userDoc.data()?['pseudo'] ?? "Inconnu";

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final currentPoints = snapshot.data()?['points'] ?? 0;
        transaction.update(userRef, {'points': currentPoints + _score});
      });

      // Ajout des points dans le classement hebdomadaire
      final weeklyRef = FirebaseFirestore.instance.collection('weekly_leaderboard').doc(weekId);
      await weeklyRef.set({
        'start': Timestamp.fromDate(monday),
        'end': Timestamp.fromDate(monday.add(Duration(days: 6, hours: 23, minutes: 59))),
      }, SetOptions(merge: true));

      await weeklyRef.set({
        'points_ranking': FieldValue.arrayUnion([
          {
          'uid': user.uid,
          'pseudo': _pseudo,
          'points': _score,
          }
        ])
      }, SetOptions(merge: true));
    }
  }

  // ✅ Charge les questions du fichier JSON
  Future<void> _loadQuestions() async {
    List<String> paths = [
      "assets/data/questions_histoire.json",
      "assets/data/questions_personnalites.json",
      "assets/data/questions_faune_flore.json",
      "assets/data/questions_culture.json",
    ];

    List<Map<String, dynamic>> allQuestions = [];

    for (String path in paths) {
      String data = await rootBundle.loadString(path);
      List<dynamic> jsonResult = json.decode(data);
      allQuestions.addAll(jsonResult.cast<Map<String, dynamic>>());
    }

    setState(() {
      _questions = allQuestions;
      _selectRandomCategory();
    });
  }

  void _selectRandomCategory() {
    if (_questions.isNotEmpty) {
      List<String> availableCategories = _questions
          .where((q) => !_askedQuestions.contains("${q['categorie'].toString().trim()}|${q['question'].toString().trim()}"))
          .map((q) => q['categorie'].toString())
          .toSet()
          .toList();

      if (availableCategories.isNotEmpty) {
        _selectedCategory = availableCategories[_random.nextInt(availableCategories.length)];
        _selectedDifficulty = null;
        _currentQuestion = null;

        // Vérifie les difficultés disponibles pour cette catégorie
        List<String> availableDifficulties = ["Facile", "Moyen", "Difficile"].where((diff) {
          return _questions.any((q) =>
            q['categorie'] == _selectedCategory &&
            q['difficulte'] == diff &&
            !_askedQuestions.contains("${q['categorie'].toString().trim()}|${q['question'].toString().trim()}")
          );
        }).toList();

        // Si aucune difficulté dispo, on passe à une autre catégorie
        if (availableDifficulties.isEmpty) {
          _selectRandomCategory();
        }
      } else {
        _showResults(); // Toutes les questions ont été posées
      }
    }
  }

  // ✅ Démarre le timer
  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        if (_timeLeft == 11) {
          _timerSound.play(AssetSource('sons/quiz/timer.mp3'));
        }
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
        _showResults();
        _timerSound.stop();
        _endSound.play(AssetSource('sons/quiz/explose.mp3'));
      }
    });
  }

  void _pickRandomQuestion(String difficulty) {
    List<Map<String, dynamic>> filteredQuestions = _questions
        .where((q) =>
            q['categorie'] == _selectedCategory &&
            q['difficulte'] == difficulty &&
            !_askedQuestions.contains("${q['categorie'].toString().trim()}|${q['question'].toString().trim()}"))
        .toList();

    if (filteredQuestions.isNotEmpty) {
      Map<String, dynamic> selected = filteredQuestions[_random.nextInt(filteredQuestions.length)];
      setState(() {
        _selectedDifficulty = difficulty;
        _currentQuestion = selected;
        _answered = false;
        _askedQuestions.add("${selected['categorie'].toString().trim()}|${selected['question'].toString().trim()}");
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Plus de questions disponibles pour cette difficulté. Nouvelle catégorie...")),
      );
      setState(() {
        _selectedDifficulty = null;
        _currentQuestion = null;
      });
      _selectRandomCategory(); // Relance avec une autre catégorie
    }
  }

  // ✅ Vérifie la réponse et ajoute du temps si correcte
  void _checkAnswer(bool isCorrect, TapDownDetails details) {
    if (_answered) return;

    _tapPosition = details.globalPosition;
    if (isCorrect) {
      _correctSound.play(AssetSource('sons/quiz/correct.mp3'));
    } else {
      _wrongSound.play(AssetSource('sons/quiz/false.mp3'));
    }
    setState(() {
      _answered = true;
      if (isCorrect) {
        _score += _difficultyPoints[_selectedDifficulty]!;
        _addBonusTime(_selectedDifficulty!);
        _scoreGained = _difficultyPoints[_selectedDifficulty]!;
        _scoreBubblePosition = _tapPosition;
        _showScoreBubble = true;
        _scoreBubbleController.forward(from: 0.0);
        _showAnimation = true;
        _animationAsset = _selectedDifficulty == "Facile"
            ? 'assets/lottie/starexplose_facile.json'
            : _selectedDifficulty == "Moyen"
                ? 'assets/lottie/starexplose_moyen.json'
                : 'assets/lottie/starexplose_difficile.json';
      } else {
        if (_selectedDifficulty == "Facile") {
          _score -= 1;
        } else if (_selectedDifficulty == "Moyen") {
          _score -= 3;
        } else if (_selectedDifficulty == "Difficile") {
          _score -= 6;
        }
        if (_score < 0) _score = 0;
        _scoreGained = -(_selectedDifficulty == "Facile" ? 1 : _selectedDifficulty == "Moyen" ? 3 : 6);
        _scoreBubblePosition = _tapPosition;
        _showScoreBubble = true;
        _scoreBubbleController.forward(from: 0.0);
        _showAnimation = false;
      }
    });
    _scorePulseController.forward(from: 0.0);

    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _showAnimation = false;
        if (_timeLeft > 0) {
          _selectedCategory = null;
          _selectedDifficulty = null;
          _currentQuestion = null;
          _selectRandomCategory();
        }
      });
      if (_timeLeft <= 0) {
        _showResults();
      }
    });
  }

  // ✅ Ajoute du temps et illumine le timer en vert
  void _addBonusTime(String difficulty) {
    setState(() {
      _timeLeft += _bonusTime[difficulty]!;
      _timerHighlight = true;
    });

    Future.delayed(Duration(milliseconds: 800), () {
      setState(() {
        _timerHighlight = false;
      });
    });
  }

  // ✅ Affiche les résultats à la fin du quiz
  void _showResults() {
    _saveScoreToDatabase();
    FirebaseAnalytics.instance.logEvent(
      name: 'defi_quiz_ended',
      parameters: {
        'score': _score,
        'questions_answered': _askedQuestions.length,
        'duration': 60,
        'pseudo': _pseudo,
      },
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/rocherplage.png"),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "🎉 Quiz Terminé !",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Ton score est de $_score points",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  FirebaseFirestore.instance.collection('defi_quiz_stats').add({
                    'uid': FirebaseAuth.instance.currentUser?.uid ?? "inconnu",
                    'pseudo': _pseudo,
                    'score': _score,
                    'date': Timestamp.now(),
                    'duration': 60, // durée initiale
                    'questions_answered': _askedQuestions.length,
                  }).then((_) {
                    AdService.showInterstitial();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    Navigator.pushReplacementNamed(context, '/defis_quiz_menu');
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: Text(
                  "Retour",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    BackgroundMusicService.instance.resume();
    _timer?.cancel();
    _scoreBubbleController.dispose();
    _scorePulseController.dispose();
    _audioPlayer.stop();
    _correctSound.dispose();
    _wrongSound.dispose();
    _timerSound.dispose();
    _endSound.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double fontSize = MediaQuery.of(context).size.width < 400 ? 16 : 20;

    if (_showIntroCard) {
      return Scaffold(
        body: Container(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _scorePulseController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 5 * sin(_scorePulseController.value * 2 * pi)),
                    child: Image.asset(
                      'assets/images/boiscartoon.png',
                      fit: BoxFit.cover,
                      height: double.infinity,
                      width: double.infinity,
                    ),
                  );
                },
              ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 16),

                        SizedBox(height: 16),
                        Text(
                          "🎯 Objectif : Réponds correctement à un maximum de questions en 60 secondes.\n\n"
                          "🕓 Le chrono commence dès que tu démarres. Plus tu réponds vite et juste, plus tu marques de points !\n\n"
                          "🎮 À chaque nouvelle question, choisis un niveau de difficulté :\n\n"
                          "🥉 Facile : +5 points si bonne réponse | +1 seconde bonus | -1 point si erreur\n"
                          "🥈 Moyen : +10 points | +2 secondes | -3 points si erreur\n"
                          "🥇 Difficile : +15 points | +3 secondes | -6 points si erreur\n\n"
                          "💡 Attention : Si tu te trompes, tu perds des points !\n\n"
                          "🏆 Ton score final sera enregistré pour le classement hebdomadaire.",
                          textAlign: TextAlign.left,
                          style: TextStyle(fontSize: 16, height: 1.5),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showIntroCard = false;
                            });
                            _startTimer();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text("Commencer le quiz", style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Défi"),
        backgroundColor: Colors.orangeAccent,
        actions: [
          Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(Icons.timer, color: Colors.white),
                SizedBox(width: 5),
                AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    color: _timerHighlight ? Colors.greenAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    "$_timeLeft s",
                    style: TextStyle(fontSize: fontSize, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                // 🔹 Barre de progression animée du temps
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: _timeLeft / 60,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timeLeft > 30
                            ? Colors.green
                            : _timeLeft > 15
                                ? Colors.orange
                                : Colors.red,
                      ),
                      minHeight: 12,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepOrange, Colors.orangeAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        "Score : $_score",
                        style: TextStyle(
                          fontSize: fontSize + 4,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                if (false) // Suppression du choix manuel de catégorie
                  Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Choisissez une catégorie :", style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold)),
                          SizedBox(height: 20),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _questions
                                .where((q) => !_askedQuestions.contains("${q['categorie']}|${q['question']}"))
                                .map((q) => q['categorie'].toString())
                                .toSet()
                                .map((cat) => ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedCategory = cat;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                        backgroundColor: Colors.orange,
                                      ),
                                      child: Text(cat, textAlign: TextAlign.center),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_selectedDifficulty == null)
                  Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedCategory != null)
                            Text(
                              _selectedCategory!,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent),
                            ),
                          SizedBox(height: 15),
                          Text("Choisissez la difficulté :", style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
                          SizedBox(height: 15),
                          Column(
                            children: ["Facile", "Moyen", "Difficile"].map((level) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: SizedBox(
                                  width: 250,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _questions.any((q) =>
                                        q['categorie'] == _selectedCategory &&
                                        q['difficulte'] == level &&
                                        !_askedQuestions.contains("${q['categorie'].toString().trim()}|${q['question'].toString().trim()}"))
                                        ? () => _pickRandomQuestion(level)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueGrey,
                                      elevation: 5,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text(
                                      "${level.toUpperCase()} (${_difficultyPoints[level]} pts)",
                                      style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 30),
                          Image.asset('assets/images/logo.png', height: 200),
                        ],
                      ),
                    ),
                  ),
                if (_currentQuestion != null) ...[
                  Card(
                    elevation: 6,
                    margin: EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade300, Colors.deepOrange.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _currentQuestion!['question'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize + 1,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Roboto',
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),

                  ..._currentQuestion!['reponses'].map<Widget>((answer) {
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) => _checkAnswer(answer['correct'], details),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(vertical: 10),
                      padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: _answered
                              ? (answer['correct']
                                  ? [Colors.green.shade400, Colors.green.shade600]
                                  : [Colors.red.shade400, Colors.red.shade600])
                              : [Colors.blue.shade300, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            offset: Offset(2, 4),
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.8,
                        child: AutoSizeText(
                          answer['texte'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize + 2,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Roboto',
                            shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1))],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          minFontSize: 12,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                  );
                  }).toList(),
                ],
              ],
            ),
          ),
          ),
          if (_showAnimation && _tapPosition != null)
            Positioned(
              left: _tapPosition!.dx - 50,
              top: _tapPosition!.dy - 50 - MediaQuery.of(context).padding.top - kToolbarHeight,
              child: SizedBox(
                width: 100,
                height: 100,
                child: Lottie.asset(_animationAsset),
              ),
            ),
          if (_showScoreBubble && _scoreBubblePosition != null && _scoreGained != null)
            Positioned(
              left: _scoreBubblePosition!.dx - 25,
              top: _scoreBubblePosition!.dy - 180,
              child: AnimatedBuilder(
                animation: _scoreBubbleController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _scoreBubbleFadeAnimation.value,
                    child: Transform.translate(
                      offset: (_scoreGained! > 0 ? _scoreBubbleSlideAnimation.value : Offset(0, 1 - _scoreBubbleSlideAnimation.value.dy)) * 80,
                      child: Transform.scale(
                        scale: _scoreBubbleScaleAnimation.value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _scoreGained! > 0 ? (_selectedDifficulty == "Facile"
                        ? Colors.yellow
                        : _selectedDifficulty == "Moyen"
                            ? Colors.blue
                            : Colors.green)
                        : Colors.black,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: Text(
                    '${_scoreGained! > 0 ? '+' : ''}${_scoreGained!}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _scoreGained! > 0 ? (_selectedDifficulty == "Facile" ? Colors.green : Colors.yellow) : Colors.white,
                    ),
                  )
                ),
              ),
            ),
        ],
      ),
    );
  }
}
