import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/favorite_service.dart';
import 'classement/classement_perso_screen.dart';
import 'duel_screens/domain_selection_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoriteService _favoriteService = FavoriteService();
  StreamSubscription<List<String>>? _favSub;
  List<Map<String, dynamic>> _favoriteUsers = [];
  bool _loading = true;
  bool _isSendingRequest = false;
  bool _loggedIn = true;

  @override
  void initState() {
    super.initState();
    _listenFavorites();
  }

  void _listenFavorites() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _loggedIn = false;
      });
      return;
    }
    _favSub = _favoriteService.favoritesStream(uid).listen((uids) {
      _fetchUsers(uids);
    });
  }

  Future<void> _fetchUsers(List<String> uids) async {
    if (uids.isEmpty) {
      setState(() {
        _favoriteUsers = [];
        _loading = false;
      });
      return;
    }

    final futures = uids.map((id) =>
        FirebaseFirestore.instance.collection('users').doc(id).get());
    final docs = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _favoriteUsers = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'uid': doc.id,
          'pseudo': data['pseudo'] ?? 'Sans pseudo',
          'avatar': data['avatar'] ?? 'avatar_default.png',
        };
      }).toList();
      _loading = false;
    });
  }

  Future<void> _removeFavorite(String uid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    await _favoriteService.removeFavorite(currentUser.uid, uid);
  }

  Future<void> _sendDuelRequest(String opponentId, String opponentPseudo) async {
    if (_isSendingRequest) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (opponentId == currentUser?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous ne pouvez pas vous défier vous-même.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSendingRequest = true);

    if (currentUser == null) return;

    final selectedDomains = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DomainSelectionScreen()),
    );

    if (selectedDomains == null || selectedDomains.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez choisir exactement 6 domaines.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSendingRequest = false);
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

    await FirebaseFirestore.instance.collection('duels').add(duelData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Défi envoyé avec succès !'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() => _isSendingRequest = false);
  }

  @override
  void dispose() {
    _favSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes favoris')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_loggedIn
              ? const Center(
                  child: Text('Veuillez vous connecter pour voir vos favoris.'),
                )
              : _favoriteUsers.isEmpty
                  ? const Center(child: Text('Aucun favori.'))
                  : ListView.builder(
                  itemCount: _favoriteUsers.length,
                  itemBuilder: (context, index) {
                    final user = _favoriteUsers[index];
                    return ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClassementPersoScreen(userId: user['uid']),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          backgroundImage: AssetImage('assets/images/avatars/${user['avatar']}'),
                        ),
                      ),
                      title: Text(user['pseudo']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeFavorite(user['uid']),
                          ),
                          InkWell(
                            onTap: () => _sendDuelRequest(user['uid'], user['pseudo']),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                image: const DecorationImage(
                                  image: AssetImage('assets/images/boiscartoon.png'),
                                  fit: BoxFit.cover,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Défier',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
