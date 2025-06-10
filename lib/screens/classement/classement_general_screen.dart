import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'classement_perso_screen.dart';

class ClassementGeneralScreen extends StatefulWidget {
  const ClassementGeneralScreen({Key? key}) : super(key: key);

  @override
  State<ClassementGeneralScreen> createState() => _ClassementGeneralScreenState();
}

class _ClassementGeneralScreenState extends State<ClassementGeneralScreen> {
  final ScrollController _scrollController = ScrollController();

  int _calculateStars(int points) {
    if (points >= 40000) return 5;
    if (points >= 20000) return 4;
    if (points >= 5000) return 3;
    if (points >= 1000) return 2;
    return 1;
  }

  void _scrollToCurrentUser(List<QueryDocumentSnapshot> users) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid; // get current user ID
    final index = users.indexWhere((doc) => doc.id == currentUserId);
    if (index != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          index * 78.0, // approx height of each card
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  Widget _buildList(Future<QuerySnapshot> future, bool isPoints) {
    return FutureBuilder<QuerySnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final users = snapshot.data!.docs;
        _scrollToCurrentUser(users);

        return ListView.builder(
          controller: _scrollController,
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            final pseudo = data['pseudo'] ?? 'Anonyme';
            final avatar = data['avatar'] ?? '1.png';
            final points = data['points'] ?? 0;
            final wins = data['totalWins'] ?? 0;
            final stars = _calculateStars(points);
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final isCurrentUser = users[index].id == currentUserId;

            return Card(
              color: isCurrentUser ? Colors.green.withOpacity(0.8) : Colors.blue.shade600.withOpacity(0.5),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClassementPersoScreen(userId: users[index].id),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage: AssetImage('assets/images/avatars/$avatar'),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  pseudo,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: isPoints
                    ? Row(
                        children: List.generate(stars, (i) => const Icon(Icons.star, color: Colors.amber, size: 16)),
                      )
                    : null,
                trailing: Text(
                  isPoints ? '$points pts' : '$wins victoires',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('Classement Général'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Points'),
              Tab(text: 'Victoires'),
            ],
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/paysage.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: TabBarView(
                children: [
                  _buildList(
                    FirebaseFirestore.instance.collection('users').orderBy('points', descending: true).limit(100).get(),
                    true,
                  ),
                  _buildList(
                    FirebaseFirestore.instance.collection('users').orderBy('totalWins', descending: true).limit(100).get(),
                    false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
