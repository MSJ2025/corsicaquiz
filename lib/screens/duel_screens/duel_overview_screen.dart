import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'duel_game_screen.dart';
import 'duel_result_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:rxdart/rxdart.dart' as rx;

class DuelOverviewScreen extends StatefulWidget {
  const DuelOverviewScreen({Key? key}) : super(key: key);

  @override
  State<DuelOverviewScreen> createState() => _DuelOverviewScreenState();
}

class _DuelOverviewScreenState extends State<DuelOverviewScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  // final PageController pageController = PageController();

  Stream<List<QuerySnapshot>> combineStreamsOnce(Stream<QuerySnapshot> a, Stream<QuerySnapshot> b) {
    return rx.Rx.combineLatest2<QuerySnapshot, QuerySnapshot, List<QuerySnapshot>>(
      a,
      b,
      (snapshotA, snapshotB) => [snapshotA, snapshotB],
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -0.4, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  child: Lottie.asset(
                    'assets/lottie/sun3.json',
                    repeat: true,
                  ),
                ),
                Positioned(
                  top: 26,
                  left: 26,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_circle_left_rounded, color: Colors.white70, size: 50),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            top: 200,
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/boiscartoon.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: const TabBar(
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: [
                        Tab(text: 'Acceptés'),
                        Tab(text: 'En attente'),
                        Tab(text: 'Historique'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            color: Colors.blueGrey.withOpacity(0.75),
                            child: _buildDuelList(context, 'accepted'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            color: Colors.blueGrey.withOpacity(0.75),
                            child: _buildPendingRequestsList(context),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            color: Colors.blueGrey.withOpacity(0.75),
                            child: _buildHistoryList(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuelList(BuildContext context, String status) {
    final currentUser = FirebaseAuth.instance.currentUser;

    final fromStream = FirebaseFirestore.instance
        .collection('duels')
        .where('status', isEqualTo: status)
        .where('from', isEqualTo: currentUser?.uid)
        .snapshots();

    final toStream = FirebaseFirestore.instance
        .collection('duels')
        .where('status', isEqualTo: status)
        .where('to', isEqualTo: currentUser?.uid)
        .snapshots();

    return StreamBuilder<List<QuerySnapshot>>(
      stream: combineStreamsOnce(
        FirebaseFirestore.instance
            .collection('duels')
            .where('status', isEqualTo: status)
            .where('from', isEqualTo: currentUser?.uid)
            .snapshots(),
        FirebaseFirestore.instance
            .collection('duels')
            .where('status', isEqualTo: status)
            .where('to', isEqualTo: currentUser?.uid)
            .snapshots(),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = [
          ...snapshot.data![0].docs,
          ...snapshot.data![1].docs,
        ];

        final allToPlay = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final totalQuestions = data['questions']?.length ?? 0;
          final isFrom = data['from'] == currentUser?.uid;

          final myIndex = isFrom
              ? (data['player1']?['currentIndex'] ?? 0)
              : (data['player2']?['currentIndex'] ?? 0);

          return myIndex < totalQuestions;
        }).toList();

        if (allToPlay.isEmpty) {
          return const Center(child: Text('Aucune donnée'));
        }

        return ListView.builder(
          itemCount: allToPlay.length,
          itemBuilder: (context, index) {
            final duel = allToPlay[index];
            final data = duel.data() as Map<String, dynamic>;
            final opponent = (data['player1']?['uid'] == currentUser?.uid)
                ? (data['player2']?['pseudo'] ?? 'Adversaire inconnu')
                : (data['player1']?['pseudo'] ?? 'Adversaire inconnu');
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DuelGameScreen(duelId: duel.id),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    color: Colors.white.withOpacity(0.92),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 12.0),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundImage: AssetImage(
                                'assets/images/avatar_placeholder.png'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Défi contre $opponent',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17)),
                                const SizedBox(height: 4),
                                const Text('Tu peux maintenant répondre à ce duel !',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.black54)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingRequestsList(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('duels')
          .where('to', isEqualTo: currentUser?.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;

        if (requests.isEmpty) {
          return const Center(child: Text('Aucun défi en attente.'));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final fromUser = data['from'];

            return ListTile(
              title: Text('Défi reçu de $fromUser'),
              subtitle: Text('Statut: ${data['status']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _respondToDuel(request.id, true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _respondToDuel(request.id, false),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _respondToDuel(String duelId, bool accept) async {
    final newStatus = accept ? 'accepted' : 'refused';
    await FirebaseFirestore.instance
        .collection('duels')
        .doc(duelId)
        .update({'status': newStatus});

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  Widget _buildHistoryList(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('duels')
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        final completed = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isFrom = data['from'] == currentUser?.uid;
          final isTo = data['to'] == currentUser?.uid;
          final total = data['questions']?.length ?? 0;
          final current1 = data['player1']?['currentIndex'] ?? 0;
          final current2 = data['player2']?['currentIndex'] ?? 0;

          return (isFrom || isTo) && current1 >= total && current2 >= total;
        }).toList();

        // Suppression automatique des anciens duels terminés au-delà des 10 derniers
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (completed.length > 10 && userId != null) {
          final excess = completed.length - 10;
          final sorted = List.from(completed)..sort((a, b) {
            final at = (a.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
            final bt = (b.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
            return (at as Timestamp).compareTo(bt as Timestamp);
          });
          for (var duel in sorted.take(excess)) {
            FirebaseFirestore.instance.collection('duels').doc(duel.id).delete();
          }
        }

        if (completed.isEmpty) {
          return const Center(child: Text('Aucun résultat disponible.'));
        }

        return ListView.builder(
          itemCount: completed.length,
          itemBuilder: (context, index) {
            final duel = completed[index];
            final data = duel.data() as Map<String, dynamic>;
            final opponent = (data['player1']?['uid'] == currentUser?.uid)
                ? (data['player2']?['pseudo'] ?? 'Adversaire inconnu')
                : (data['player1']?['pseudo'] ?? 'Adversaire inconnu');

            final userId = FirebaseAuth.instance.currentUser?.uid;
            final score1 = data['player1']?['score'] ?? 0;
            final score2 = data['player2']?['score'] ?? 0;
            final isUserPlayer1 = data['player1']?['uid'] == userId;

            String resultLabel = 'Égalité';
            IconData resultIcon = Icons.thumbs_up_down;
            Color cardColor = Colors.yellow.shade100;

            if ((isUserPlayer1 && score1 > score2) || (!isUserPlayer1 && score2 > score1)) {
              resultLabel = 'Victoire';
              resultIcon = Icons.emoji_events;
              cardColor = Colors.green.shade100;
            } else if ((isUserPlayer1 && score1 < score2) || (!isUserPlayer1 && score2 < score1)) {
              resultLabel = 'Défaite';
              resultIcon = Icons.cancel;
              cardColor = Colors.red.shade100;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DuelResultScreen(duelId: duel.id),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                      child: Row(
                        children: [
                          Icon(resultIcon, color: Colors.black87, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Défi contre $opponent',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('Résultat : $resultLabel',
                                    style: const TextStyle(fontSize: 14, color: Colors.black54)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
