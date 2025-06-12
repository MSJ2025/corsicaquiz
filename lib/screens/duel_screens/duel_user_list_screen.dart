import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../classement/classement_perso_screen.dart';
import 'domain_selection_screen.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/favorite_service.dart';

class DuelUserListScreen extends StatefulWidget {
  const DuelUserListScreen({Key? key}) : super(key: key);

  @override
  State<DuelUserListScreen> createState() => _DuelUserListScreenState();
}

class _DuelUserListScreenState extends State<DuelUserListScreen> {
  String searchQuery = '';
  bool _isSendingRequest = false;
  final FavoriteService _favoriteService = FavoriteService();
  Set<String> _favorites = {};
  StreamSubscription<List<String>>? _favSub;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _favSub = _favoriteService.favoritesStream(uid).listen((fav) {
        setState(() => _favorites = fav.toSet());
      });
    }
  }

  @override
  void dispose() {
    _favSub?.cancel();
    super.dispose();
  }

  Future<void> sendDuelRequest(String opponentId, String opponentPseudo) async {
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
    setState(() {
      _isSendingRequest = true;
    });

    if (currentUser == null) return;

    // Affichage de l'écran de sélection des domaines pour le créateur
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
        _isSendingRequest = false;
      });
      return;
    }

    final myId = currentUser.uid;
    final mySnapshot = await FirebaseFirestore.instance.collection('users').doc(myId).get();
    final myPseudo = mySnapshot.data()?['pseudo'] ?? 'Joueur';
    debugPrint('sendDuelRequest: myId=$myId, opponentId=$opponentId, opponentPseudo=$opponentPseudo');

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

    // Pour chaque difficulté, pour chaque domaine sélectionné, ajouter une question si nécessaire
    for (final difficulty in difficultyMap.keys) {
      final filteredDomains = List<String>.from(selectedDomains);
      filteredDomains.shuffle();

      for (final domain in filteredDomains) {
        // Vérifie si le nombre de questions pour cette difficulté est déjà atteint
        if (allQuestions.where((q) => q['difficulte'] == difficulty).length >= difficultyMap[difficulty]!) break;

        final questions = await loadJson('assets/data/$domain.json');
        final filtered = (questions as List).where((q) => q['difficulte'] == difficulty).toList();
        filtered.shuffle();
        if (filtered.isNotEmpty) {
          allQuestions.add(filtered.first);
        }
      }
    }

    debugPrint('sendDuelRequest: Total questions generated: ${allQuestions.length}');

    // Préparer les données du duel, en ajoutant le champ 'domainesEnvoyeur'
    final duelData = {
      'from': myId,
      'to': opponentId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'questions': allQuestions,
      'domainesEnvoyeur': selectedDomains, // Ce champ contient les 6 domaines sélectionnés par le créateur
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
      'lastOpened_$myId': FieldValue.serverTimestamp(),
      'lastOpened_$opponentId': null,
    };

    final duelRef = await FirebaseFirestore.instance.collection('duels').add(duelData);
    debugPrint('sendDuelRequest: Duel request sent successfully. Duel ID: ${duelRef.id}');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Défi envoyé avec succès !'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      _isSendingRequest = false;
    });
  }

  Future<void> _toggleFavorite(String uid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      if (_favorites.contains(uid)) {
        await _favoriteService.removeFavorite(currentUser.uid, uid);
        setState(() => _favorites.remove(uid));
      } else {
        await _favoriteService.addFavorite(currentUser.uid, uid);
        setState(() => _favorites.add(uid));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la mise à jour des favoris.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/duel.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Lottie.asset('assets/lottie/clouds.json', fit: BoxFit.cover),
          Positioned(
            top: 60,
            left: 20,
            child: Stack(
              alignment: Alignment.topLeft,
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: Lottie.asset('assets/lottie/sun3.json', repeat: true),
                ),
                Positioned(
                  top: 26,
                  left: 26,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 50),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            top: 200,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  height: 60,
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/boiscartoon.png'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Trouver un adversaire',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Rechercher un joueur',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(
                      _showFavoritesOnly ? Icons.star : Icons.star_border,
                      color: Colors.orangeAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        _showFavoritesOnly = !_showFavoritesOnly;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allUsers = snapshot.data!.docs;
                      var filteredUsers = allUsers
                        .where((doc) => doc.id != currentUser?.uid)
                        .map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return {
                            'uid': doc.id,
                            'pseudo': data['pseudo'] ?? 'Sans pseudo',
                            'online': data.containsKey('online') ? data['online'] : false,
                            'points': data['points'] ?? 0,
                            'avatar': data['avatar'] ?? 'avatar_default.png',
                          };
                        })
                        .where((user) => user['pseudo'].toLowerCase().contains(searchQuery.toLowerCase()))
                        .toList();
                      if (_showFavoritesOnly) {
                        filteredUsers = filteredUsers.where((u) => _favorites.contains(u['uid'])).toList();
                      }
                      // Trier les utilisateurs par ordre alphabétique de pseudo
                      filteredUsers.sort((a, b) => a['pseudo'].toString().toLowerCase().compareTo(b['pseudo'].toString().toLowerCase()));

                      if (filteredUsers.isEmpty) {
                        return const Center(child: Text('Aucun autre utilisateur trouvé.'));
                      }

                      return ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final uid = user['uid'];
                          final pseudo = user['pseudo'];
                          final points = user['points'] ?? 0;
                          final avatar = user['avatar'] ?? 'avatar_default.png';
                          int stars = 1;
                          if (points >= 1000) stars = 2;
                          if (points >= 5000) stars = 3;
                          if (points >= 20000) stars = 4;
                          if (points >= 40000) stars = 5;
                          final isOnline = user['online'] ?? false;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 5,
                              color: Colors.white.withOpacity(0.92),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
                                leading: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ClassementPersoScreen(userId: uid),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundImage: AssetImage('assets/images/avatars/$avatar'),
                                      ),
                                      if (isOnline)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: Colors.greenAccent,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                title: Text(pseudo,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                subtitle: Text(
                                  [
                                    if (stars > 0) List.generate(stars, (_) => '⭐').join(' '),
                                    if (user.containsKey('online')) (isOnline ? 'En ligne' : 'Hors ligne'),
                                  ].join(' • '),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _favorites.contains(uid) ? Icons.star : Icons.star_border,
                                        color: _favorites.contains(uid) ? Colors.orange : Colors.grey,
                                      ),
                                      onPressed: () => _toggleFavorite(uid),
                                    ),
                                    InkWell(
                                      onTap: () => sendDuelRequest(uid, pseudo),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: AssetImage('assets/images/boiscartoon.png'),
                                            fit: BoxFit.cover,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: Offset(2, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          'Défier',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
