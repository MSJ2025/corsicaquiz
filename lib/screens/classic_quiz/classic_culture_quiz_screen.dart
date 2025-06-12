import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/screens/classic_quiz/classic_quiz_menu_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '/services/ad_service.dart';


class ClassicCultureQuizScreen extends StatefulWidget {
  @override
  _ClassicCultureQuizScreenState createState() => _ClassicCultureQuizScreenState();
}

class _ClassicCultureQuizScreenState extends State<ClassicCultureQuizScreen> with TickerProviderStateMixin {
  Future<void> _showFinalResultCard() async {
    final bellPlayer = AudioPlayer();
    try {
      await bellPlayer.setAsset('assets/sons/quiz/bell.mp3');
      bellPlayer.play();
    } catch (e) {
      debugPrint("Erreur de lecture du son bell : \$e");
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          backgroundColor: Colors.white.withOpacity(0.95),
          insetPadding: EdgeInsets.symmetric(horizontal: 25, vertical: 40),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade100, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/gland.png', height: 70),
                SizedBox(height: 15),
                Text(
                  'Quiz terminé !',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown),
                ),
                SizedBox(height: 10),
                Text(
                  'Tu as gagné $_score glands !\nIls ont été ajoutés à ton profil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    AdService.showInterstitial();
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => ClassicQuizMenuScreen()),
                    );
                  },
                  child: Text('Retour au menu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  String? _explanation;
  Map<int, Alignment> _swingOrigins = <int, Alignment>{};
  int selectedIndex = -1;

  late AnimationController _controller;
  late Animation<double> _avatarPosition;
  late AnimationController _swingController;
  late Animation<double> _swingAnimation;
  Map<int, List<Widget>> _impactMap = {};
  late final AudioPlayer _player;
  late final AudioPlayer _gunPlayer;
  String _userAvatar = '1.png';

  Future<void> _updateGlandsInDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final currentGlands = snapshot['glands'] ?? 0;
        transaction.update(userRef, {'glands': currentGlands + _score});
      });
    }
  }
  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'classic_culture_quiz_started');
    _player = AudioPlayer();
    _gunPlayer = AudioPlayer();
    _playMusic();
    _loadQuestions();
    _loadUserAvatar();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _avatarPosition = Tween<double>(begin: 12.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
    );
    _swingController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _swingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _swingController, curve: Curves.linear),
    );
  }
  void _loadUserAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _userAvatar = data?['avatar'] ?? '1.png';
        });
      }
    }
  }

  Future<void> _loadQuestions() async {
    final String response = await rootBundle.loadString('assets/data/questions_culture.json');
    final List<dynamic> allQuestions = json.decode(response);
    final List<dynamic> easyQuestions = (allQuestions.where((q) => q['difficulte'] == 'Facile').toList()..shuffle());
    final List<dynamic> mediumQuestions = (allQuestions.where((q) => q['difficulte'] == 'Moyen').toList()..shuffle());
    final List<dynamic> hardQuestions = (allQuestions.where((q) => q['difficulte'] == 'Difficile').toList()..shuffle());

    setState(() {
      _questions = [...easyQuestions.take(4), ...mediumQuestions.take(4), ...hardQuestions.take(4)];
    });
  }

  void _showImpactsOnButton(GlobalKey key, int index, TapDownDetails details) {
    final RenderBox renderBox = key.currentContext?.findRenderObject() as RenderBox;
    final size = renderBox.size;

    final images = ['impact1.png', 'impact2.png', 'impact3.png', 'impact1.png'];
    final random = Random();
    List<Widget> newImpacts = [];

    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;

    final impactSize = 40.0;
    final safeMargin = 34.0;

    final maxX = size.width - impactSize - safeMargin;
    final maxY = size.height - impactSize - safeMargin;

    final dx = min(max(safeMargin, tapX + random.nextDouble() * 40 - 20), maxX);
    final dy = min(max(safeMargin, tapY + random.nextDouble() * 40 - 20), maxY);

    for (int i = 0; i < images.length; i++) {
      final angle = random.nextDouble() * pi * 2;
      final scale = 1.8 + random.nextDouble() * 0.9;
      final opacity = 0.6 + random.nextDouble() * 0.4;

      newImpacts.add(Positioned(
        top: dy,
        left: dx,
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Image.asset(
                'assets/images/${images[i]}',
                width: 40,
                height: 40,
              ),
            ),
          ),
        ),
      ));
    }

    setState(() {
      _impactMap[index] = newImpacts;
    });
  }

  void _checkAnswer(bool isCorrect, Map<String, dynamic> question) async {
    if (_answered) return;

    _playGunSound(); // 🔫 Joue le son du tir

    setState(() {
      _answered = true;
      _explanation = question['explication'];
      if (isCorrect) {
        _score++;
        _controller.stop();
        _controller.animateTo((_score + 1) / 12, duration: Duration(milliseconds: 700), curve: Curves.easeInOut);
      }
    });

    if (isCorrect) {
      _swingController.repeat();
      await Future.delayed(Duration(seconds: 1));
      _swingController.stop();
    }

    await Future.delayed(Duration(milliseconds: 500));

    _impactMap.clear();

    final wooshPlayer = AudioPlayer();
    try {
      await wooshPlayer.setAsset('assets/sons/quiz/woosh.mp3');
      wooshPlayer.play();
    } catch (e) {
      debugPrint("Erreur de lecture du son woosh : \$e");
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          backgroundColor: Colors.white.withOpacity(0.95),
          insetPadding: EdgeInsets.symmetric(horizontal: 25, vertical: 40),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.yellow, Colors.white, Colors.blueAccent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/lottie/cloudbird.json',
                  height: 150,
                  repeat: true,
                ),
                SizedBox(height: 10),
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.grey.shade200],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explication',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.teal.shade900,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          _explanation ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _signalerProbleme(question),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Signaler un problème'),
                ),
                SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey.shade200],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    label: Text(
                      "Capische",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (_currentIndex == _questions.length - 1) {
      await _updateGlandsInDatabase();
      await _showFinalResultCard();
    }

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _explanation = null;
      });
    }
  }

  Widget _buildVerticalScoreBar() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 60,
        height: double.infinity,
        margin: EdgeInsets.only(right: 0),
        child: Stack(
          children: [

            // ✅ Glands + Avatar animés du bas vers le haut
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: List.generate(12, (index) {
                  final reverseIndex = 11 - index;
                  final glandReached = reverseIndex < _score;
                  return Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!glandReached)
                          AnimatedOpacity(
                            opacity: 1.0,
                            duration: Duration(milliseconds: 500),
                            child: Image.asset(
                              'assets/images/gland.png',
                              height: 35,
                            ),
                          ),
                        if (_score == reverseIndex || (_score == 0 && reverseIndex == 0))
                          AnimatedBuilder(
                            animation: _avatarPosition,
                            builder: (context, child) {
                              return AnimatedOpacity(
                                duration: Duration(milliseconds: 400),
                                opacity: 1.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.orange, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets.all(4),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: AssetImage('assets/images/avatars/$_userAvatar'),
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizContent() {
    final currentQuestion = _questions[_currentIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 50.0, 16.0, 16.0),
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 500),
        child: Column(
          key: ValueKey(_currentIndex),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white.withOpacity(0.95),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Text(
                  currentQuestion['question'],
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
                ),
              ),
            ),
            ...List.generate((currentQuestion['reponses'] as List).length, (i) {
              final response = currentQuestion['reponses'][i];
              final panelKey = GlobalKey();

              return GestureDetector(
                onTapDown: _answered
                    ? null
                    : (details) {
                  final box = panelKey.currentContext?.findRenderObject() as RenderBox;
                  final local = details.localPosition;
                  final width = box.size.width;
                  final alignX = (local.dx / width) * 2 - 1;
                  final alignY = -1.0;

                  final isCorrect = response['correct'];
                  Future.delayed(const Duration(milliseconds: 900), () async {
                    final soundPlayer = AudioPlayer();
                    await soundPlayer.setAsset(isCorrect
                        ? 'assets/sons/quiz/correct.mp3'
                        : 'assets/sons/quiz/pig.mp3');
                    soundPlayer.play();
                  });
                  if (isCorrect) {
                    _swingOrigins[i] = Alignment(alignX, alignY);
                  }

                  _showImpactsOnButton(panelKey, i, details);
                  _checkAnswer(isCorrect, currentQuestion as Map<String, dynamic>);
                  setState(() {
                    selectedIndex = i;
                  });
                },
                child: AnimatedBuilder(
                  animation: _swingController,
                  builder: (context, child) {
                    final isCurrent = _answered && response['correct'] && selectedIndex == i;
                    final shakeOffset = isCurrent ? sin(_swingAnimation.value * 10) * 4 : 0.0;

                    return Transform.translate(
                      offset: Offset(shakeOffset, 0),
                      child: child!,
                    );
                  },
                  child: Container(
                    key: panelKey,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    height: MediaQuery.of(context).size.height * 0.12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/panneau.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text(
                              response['texte'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'CaracteresL1',
                                fontSize: 18,
                                color: _answered
                                    ? (response['correct']
                                    ? Colors.green
                                    : (selectedIndex == i ? Colors.red : Colors.black))
                                    : Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (_impactMap.containsKey(i))
                          ..._impactMap[i]!,
                      ],
                    ),
                  ),
                ),
              );
            }).toList()..sort((a, b) => (a.key == selectedIndex ? 1 : 0) - (b.key == selectedIndex ? 1 : 0)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _swingController.dispose();
    _player.dispose();
    _gunPlayer.dispose();
    super.dispose();
  }

  void _playMusic() async {
    try {
      await _player.setAsset('assets/sons/quiz/montagne.mp3');
      await _player.setLoopMode(LoopMode.all);
      _player.play();
    } catch (e) {
      debugPrint("Erreur lors de la lecture du son : $e");
    }
  }

  void _playGunSound() async {
    try {
      await _gunPlayer.setAsset('assets/sons/quiz/gun2.mp3');
      _gunPlayer.play();
    } catch (e) {
      debugPrint("Erreur de lecture du son de tir : $e");
    }
  }

  void _signalerProbleme(Map<String, dynamic> question) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('Signaler un problème'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Décrivez le problème rencontré avec cette question',
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Merci ! Le problème a été signalé.'),
                  ),
                );
              },
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Fond dégradé
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.white, Colors.green.shade900],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 🔹 Animation nuages en haut
          Positioned(
            top: 0,
            left: -30,
            right: -35,
            child: Lottie.asset('assets/lottie/clouds.json', height: 300),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Lottie.asset('assets/lottie/clouds.json', height: 800),
          ),

          // 🔹 Animation en bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/murcartoon.png',
              fit: BoxFit.cover,
              height: 200,
            ),
          ),
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/gland.png', height: 32),
                SizedBox(height: 1),
                Text(
                  '$_score',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade800,
                  ),
                ),
              ],
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: _buildQuizContent(),
                    ),
                  ),
                  Container(
                    width: 40,
                    child: _buildVerticalScoreBar(),
                  ),
                ],
              ),
            ),
          ),

          // 🔹 AppBar personnalisée avec retour
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white70, size: 32),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
