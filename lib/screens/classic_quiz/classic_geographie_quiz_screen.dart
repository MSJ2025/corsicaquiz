import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:lottie/lottie.dart';
import 'classic_quiz_menu_screen.dart';

class ClassicGeographieQuizScreen extends StatefulWidget {
  ClassicGeographieQuizScreen({super.key});

  @override
  State<ClassicGeographieQuizScreen> createState() => _ClassicGeographieQuizScreenState();
}

class _ClassicGeographieQuizScreenState extends State<ClassicGeographieQuizScreen> with TickerProviderStateMixin {
  final flutter_map.MapController _mapController = flutter_map.MapController();
  List<dynamic> _cities = [];
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
    final data = await rootBundle.loadString('assets/data/questions_geographie.json');
    setState(() {
      _cities = json.decode(data);
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

  void _onTap(dynamic pos, latlong2.LatLng latlng) {
    if (_answered || _cities.isEmpty) return;
    final city = _cities[_current];

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
      _controller.animateTo((_score + 1) / 12,
          duration: Duration(milliseconds: 700), curve: Curves.easeInOut);
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
              Text('Score : $_score / 12', textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (c) => ClassicQuizMenuScreen()),
                  );
                },
                child: Text('Retour au menu'),
              )
            ],
          ),
        ),
      ),
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
                  child: Text('Où se situe ${city['ville']} ?'),
                ),
                SizedBox(height: 8),
                Text('Score : $_score / 12', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}