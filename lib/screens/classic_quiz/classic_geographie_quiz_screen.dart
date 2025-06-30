import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:lottie/lottie.dart';
import 'package:just_audio/just_audio.dart';
import 'classic_quiz_menu_screen.dart';
import '/services/ad_service.dart';
import '../../services/background_music_service.dart';
import '../../services/question_history_service.dart';
import '../login_screen.dart';

class ClassicGeographieQuizScreen extends StatefulWidget {
  ClassicGeographieQuizScreen({super.key});

  @override
  State<ClassicGeographieQuizScreen> createState() => _ClassicGeographieQuizScreenState();
}

class _ClassicGeographieQuizScreenState extends State<ClassicGeographieQuizScreen> with TickerProviderStateMixin {
  final flutter_map.MapController _mapController = flutter_map.MapController();
  List<dynamic> _cities = [];
  Set<String> _questionHistory = {};
  int _current = 0;
  int _score = 0;
  latlong2.LatLng? _selected;
  bool _answered = false;
  bool _showRadius = false;
  late AnimationController _controller;
  late Animation<double> _avatarPosition;
  String _userAvatar = '1.png';

  @override
  void initState() {
    super.initState();
    BackgroundMusicService.instance.pause();
    _loadCities();
    _loadUserAvatar();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _avatarPosition = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadCities() async {
    final history = await QuestionHistoryService().loadHistory();
    _questionHistory = history.toSet();

    final data = await rootBundle
        .loadString('assets/data/questions_geographie.json');
    final allCities = json.decode(data) as List<dynamic>;

    final List<dynamic> easyCities =
        (allCities.where((c) => c['difficulte'] == 'Facile').toList()..shuffle());
    final List<dynamic> mediumCities =
        (allCities.where((c) => c['difficulte'] == 'Moyen').toList()..shuffle());
    final List<dynamic> hardCities =
        (allCities.where((c) => c['difficulte'] == 'Difficile').toList()
          ..shuffle());

    String key(Map c) => "Geographie|${c['nom'].toString().trim()}";

    List<dynamic> select(List<dynamic> source) {
      final fresh = source.where((c) => !history.contains(key(c))).toList();
      if (fresh.length < 4) {
        fresh.addAll(source.where((c) => !fresh.contains(c)).take(4 - fresh.length));
      }
      return fresh.take(4).toList();
    }

    final selectedCities = [
      ...select(easyCities),
      ...select(mediumCities),
      ...select(hardCities)
    ]
      ..shuffle();

    setState(() {
      _cities = selectedCities;
    });
  }

  Future<void> _updateGlandsInDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = snap['glands'] ?? 0;
        tx.update(ref, {'glands': current + _score});
      });
    }
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

  void _onTap(dynamic pos, latlong2.LatLng latlng) async {
    if (_answered || _cities.isEmpty) return;
    final city = _cities[_current];

    final key = "Geographie|${city['nom'].toString().trim()}";
    await QuestionHistoryService().addQuestion(key);
    _questionHistory.add(key);

    final cityPoint = latlong2.LatLng(city['latitude'], city['longitude']);
    final tapPoint = latlong2.LatLng(latlng.latitude, latlng.longitude);
    final distance = latlong2.Distance().as(latlong2.LengthUnit.Kilometer, tapPoint, cityPoint);

    setState(() {
      _selected = latlong2.LatLng(latlng.latitude, latlng.longitude); // latlong2.LatLng pour affichage
      _answered = true;
      _showRadius = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Distance : ${distance.toStringAsFixed(1)} km'),
        duration: Duration(seconds: 2),
      ),
    );

    if (distance < 10) {
      _score++;
      _controller.stop();
      _controller.animateTo((_score + 1) / _cities.length,
          duration: Duration(milliseconds: 700), curve: Curves.easeInOut);
    }
    final player = AudioPlayer();
    try {
      await player.setAsset(distance < 10 ? 'assets/sons/quiz/correct.mp3' : 'assets/sons/quiz/pig.mp3');
      player.play();
    } catch (e) {
      debugPrint('Erreur de lecture du son : $e');
    }

    Future.delayed(Duration(seconds: 2), () {
      if (_current < _cities.length - 1) {
        setState(() {
          _current++;
          _selected = null;
          _answered = false;
          _showRadius = false;
        });
      } else {
        _finishQuiz();
      }
    });
  }

  Future<void> _finishQuiz() async {
    await _updateGlandsInDatabase();
    final bellPlayer = AudioPlayer();
    try {
      await bellPlayer.setAsset('assets/sons/quiz/bell.mp3');
      bellPlayer.play();
    } catch (e) {
      debugPrint("Erreur de lecture du son bell : $e");
    }
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final scoreMsg = loggedIn
        ? 'Score : \$_score / \${_cities.length}'
        : 'Score : \$_score / \${_cities.length}\nTon score ne sera pas enregistré car tu joues en invité.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/lottie/cloudbird.json', height: 120),
              SizedBox(height: 10),
              Text('Quiz terminé !', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text(scoreMsg, textAlign: TextAlign.center),
              SizedBox(height: 20),
              if (loggedIn)
                ElevatedButton(
                  onPressed: () {
                    AdService.showInterstitial();
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (c) => ClassicQuizMenuScreen()),
                    );
                  },
                  child: Text('Retour au menu'),
                )
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        AdService.showInterstitial();
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (c) => ClassicQuizMenuScreen()),
                        );
                      },
                      child: Text('Continuer en invité'),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      child: Text("S'inscrire"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                    )
                  ],
                )
            ],
          ),
        ),
      ),
    );
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

  Widget _buildVerticalScoreBar() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 60,
        height: double.infinity,
        margin: EdgeInsets.only(right: 0),
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: List.generate(_cities.length, (index) {
                  final reverseIndex = _cities.length - 1 - index;
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

  @override
  Widget build(BuildContext context) {
    if (_cities.isEmpty) {
      return Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final city = _cities[_current];
    // latlong2.LatLng pour la carte (affichage)
    final realPoint = latlong2.LatLng(city['latitude'], city['longitude']);

    return Scaffold(
      body: SafeArea(
        child: Stack(
        children: [
          flutter_map.FlutterMap(
            mapController: _mapController,
            options: flutter_map.MapOptions(
              initialCenter: latlong2.LatLng(42.039604, 9.012893),
              initialZoom: 8.5,
              minZoom: 5,
              maxZoom: 18,
              onTap: _onTap,
            ),
            children: [
              flutter_map.TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png',
                subdomains: ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.app',
              ),
              if (_selected != null)
                flutter_map.MarkerLayer(
                  markers: [
                    flutter_map.Marker(
                      point: _selected!,
                      child: Icon(Icons.my_location, color: Colors.redAccent, size: 36),
                    ),
                  ],
                ),
              if (_answered)
                flutter_map.MarkerLayer(
                  markers: [
                    flutter_map.Marker(
                      point: realPoint,
                      child: Icon(Icons.place, color: Colors.blueAccent, size: 36),
                    ),
                  ],
                ),
              if (_showRadius)
                AnimatedOpacity(
                  duration: Duration(milliseconds: 500),
                  opacity: _showRadius ? 1.0 : 0.0,
                  child: flutter_map.CircleLayer(
                    circles: [
                      flutter_map.CircleMarker(
                        point: realPoint,
                        useRadiusInMeter: true,
                        radius: 10000,
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderColor: Colors.blueAccent,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: _buildVerticalScoreBar(),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Où se situe ${city['nom']} ?'),
                ),
                SizedBox(height: 8),
                Text('Score : $_score / ${_cities.length}', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  @override
  void dispose() {
    BackgroundMusicService.instance.resume();
    _controller.dispose();
    super.dispose();
  }
}