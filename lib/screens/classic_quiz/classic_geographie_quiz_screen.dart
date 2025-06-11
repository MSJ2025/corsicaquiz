import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart';
import 'classic_quiz_menu_screen.dart';

class ClassicGeographieQuizScreen extends StatefulWidget {
  const ClassicGeographieQuizScreen({super.key});

  @override
  State<ClassicGeographieQuizScreen> createState() => _ClassicGeographieQuizScreenState();
}

class _ClassicGeographieQuizScreenState extends State<ClassicGeographieQuizScreen> {
  final MapController _mapController = MapController();
  List<dynamic> _cities = [];
  int _current = 0;
  int _score = 0;
  LatLng? _selected;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
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

  void _onTap(TapPosition pos, LatLng latlng) {
    if (_answered || _cities.isEmpty) return;
    final city = _cities[_current];
    final cityPoint = LatLng(city['latitude'], city['longitude']);
    final distance = Distance().as(LengthUnit.Kilometer, latlng, cityPoint);
    setState(() {
      _selected = latlng;
      _answered = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Distance : ${distance.toStringAsFixed(1)} km'),
        duration: const Duration(seconds: 2),
      ),
    );
    if (distance < 10) _score++;
    Future.delayed(const Duration(seconds: 2), () {
      if (_current < _cities.length - 1) {
        setState(() {
          _current++;
          _selected = null;
          _answered = false;
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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/lottie/cloudbird.json', height: 120),
              const SizedBox(height: 10),
              const Text('Quiz terminé !', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Score : $_score / 12', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (c) => ClassicQuizMenuScreen()),
                  );
                },
                child: const Text('Retour au menu'),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cities.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final city = _cities[_current];
    final realPoint = LatLng(city['latitude'], city['longitude']);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Géographie'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: const LatLng(42.039604, 9.012893),
              zoom: 7.5,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (_selected != null)
                MarkerLayer(markers: [
                  Marker(point: _selected!, builder: (ctx) => const Icon(Icons.location_on, color: Colors.red, size: 40)),
                ]),
              if (_answered)
                MarkerLayer(markers: [
                  Marker(point: realPoint, builder: (ctx) => const Icon(Icons.flag, color: Colors.blue, size: 40)),
                ]),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Où se situe ${city['ville']} ?'),
                ),
                const SizedBox(height: 8),
                Text('Score : $_score / 12', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

