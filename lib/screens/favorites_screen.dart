import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/favorite_service.dart';

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
                      leading: CircleAvatar(
                        backgroundImage: AssetImage(
                          'assets/images/avatars/${user['avatar']}',
                        ),
                      ),
                      title: Text(user['pseudo']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeFavorite(user['uid']),
                      ),
                    );
                  },
                ),
    );
  }
}
