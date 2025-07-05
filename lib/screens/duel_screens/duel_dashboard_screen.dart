import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'duel_game_screen.dart';
import 'duel_result_screen.dart';
import 'package:lottie/lottie.dart';
import 'opponent_domain_selection_screen.dart';
import 'domain_selection_screen.dart';
import '../../widgets/simple_badge.dart';
import '../../services/duel_service.dart';

Future<String?> getUserAvatar(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  return doc.exists ? doc.get('avatar') : null;
}

class DuelDashboardScreen extends StatefulWidget {
  const DuelDashboardScreen({Key? key}) : super(key: key);

  @override
  _DuelDashboardScreenState createState() => _DuelDashboardScreenState();
}

class _DuelDashboardScreenState extends State<DuelDashboardScreen> {
  User? currentUser;
  String? currentUserAvatar;
  int _acceptedUnread = 0;
  int _pendingUnread = 0;
  int _historyUnread = 0;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      getUserAvatar(currentUser?.uid ?? '').then((avatar) {
        setState(() {
          currentUserAvatar = avatar;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.white ,Colors.yellow],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text('Mes Duels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Colors.orangeAccent,
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.orangeAccent,
            tabs: [
              Tab(child: SimpleBadge(child: const Text('Acceptés'), count: _acceptedUnread)),
              Tab(child: SimpleBadge(child: const Text('En attente'), count: _pendingUnread)),
              Tab(child: SimpleBadge(child: const Text('Historique'), count: _historyUnread)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AcceptedDuelsWidget(onUnreadCount: (c) => setState(() => _acceptedUnread = c)),
            PendingDuelsWidget(onUnreadCount: (c) => setState(() => _pendingUnread = c)),
            HistoryDuelsWidget(onUnreadCount: (c) => setState(() => _historyUnread = c)),
          ],
        ),
      ),
    );
  }
}

class AcceptedDuelsWidget extends StatefulWidget {
  final ValueChanged<int> onUnreadCount;
  const AcceptedDuelsWidget({Key? key, required this.onUnreadCount}) : super(key: key);

  @override
  State<AcceptedDuelsWidget> createState() => _AcceptedDuelsWidgetState();
}

class _AcceptedDuelsWidgetState extends State<AcceptedDuelsWidget> {
  String? myAvatar;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      getUserAvatar(uid).then((a) => setState(() => myAvatar = a));
    }
  }
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final query = FirebaseFirestore.instance
        .collection('duels')
        .where('status', isEqualTo: 'accepted')
        .where('participants', arrayContains: currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: query,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final duels = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'];
          if (status != 'accepted') return false;
          final hasAllDomains = data.containsKey('domainesEnvoyeur') && data.containsKey('domainesReceveur');
          if (!hasAllDomains) return false;
          final total = (data['questions'] as List?)?.length ?? 0;
          if (total == 0) return false;

          final isFrom = data['from'] == currentUser.uid;
          final currentIndex = isFrom
              ? (data['player1']?['currentIndex'] ?? 0)
              : (data['player2']?['currentIndex'] ?? 0);
          return currentIndex < total;
        }).toList();

        final uid = currentUser.uid;
        final unread = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final updated = data['updatedAt'] as Timestamp?;
          final opened = data['lastOpened_$uid'] as Timestamp?;
          return updated != null && (opened == null || opened.toDate().isBefore(updated.toDate()));
        }).length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onUnreadCount(unread);
        });

        // Ne marque plus automatiquement les duels comme lus ici

        if (duels.isEmpty) return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/question.json', width: 200),
              const SizedBox(height: 16),
              const Text("Aucun duel pour le moment",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey)),
            ],
          ),
        );

        return ListView.builder(
          itemCount: duels.length,
          itemBuilder: (context, index) {
            final duel = duels[index];
            final data = duel.data() as Map<String, dynamic>;
            final updated = data['updatedAt'] as Timestamp?;
            final opened = data['lastOpened_${currentUser.uid}'] as Timestamp?;
            final isUnread = updated != null && (opened == null || opened.toDate().isBefore(updated.toDate()));
            final opponentUid = data['from'] == currentUser?.uid
                ? (data['player2']?['uid'] ?? '')
                : (data['player1']?['uid'] ?? '');
            final opponent = data['from'] == currentUser?.uid
                ? (data['player2']?['pseudo'] ?? 'Adversaire inconnu')
                : (data['player1']?['pseudo'] ?? 'Adversaire inconnu');
            return Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Color(0xFFa6c1ee)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(opponentUid).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const CircleAvatar(
                          radius: 32,
                          backgroundImage: AssetImage('assets/images/avatars/avatar_placeholder.png'),
                        );
                      }
                      final opponentAvatar = (snapshot.data!.data() as Map<String, dynamic>)['avatar'];

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: myAvatar != null
                                ? AssetImage('assets/images/avatars/$myAvatar')
                                : const AssetImage('assets/images/avatars/avatar_placeholder.png'),
                          ),
                          const SizedBox(width: 4),
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: opponentAvatar != null
                                ? AssetImage("assets/images/avatars/$opponentAvatar")
                                : const AssetImage('assets/images/avatars/avatar_placeholder.png'),
                          ),
                        ],
                      );
                    },
                  ),
                  title: Text(' $opponent',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87),
                  ),
                  subtitle: const Text('Contre toi',
                    style: TextStyle(color: Colors.black54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUnread)
                        const Icon(Icons.fiber_new, color: Colors.red, size: 20),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.blueAccent),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DuelGameScreen(duelId: duel.id),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class PendingDuelsWidget extends StatefulWidget {
  final ValueChanged<int> onUnreadCount;
  const PendingDuelsWidget({Key? key, required this.onUnreadCount}) : super(key: key);

  @override
  State<PendingDuelsWidget> createState() => _PendingDuelsWidgetState();
}

class _PendingDuelsWidgetState extends State<PendingDuelsWidget> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final query = FirebaseFirestore.instance
        .collection('duels')
        .where('status', isEqualTo: 'pending')
        .where('to', isEqualTo: currentUser?.uid);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        final uid = currentUser?.uid;
        final unread = requests.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final updated = data['updatedAt'] as Timestamp?;
          final opened = uid != null ? data['lastOpened_$uid'] as Timestamp? : null;
          return updated != null && (opened == null || opened.toDate().isBefore(updated.toDate()));
        }).length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onUnreadCount(unread);
        });
        if (requests.isEmpty) return const Center(child: Text("Aucun défi en attente."));



        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            final updated = data['updatedAt'] as Timestamp?;
            final opened = uid != null ? data['lastOpened_$uid'] as Timestamp? : null;
            final isUnread = updated != null && (opened == null || opened.toDate().isBefore(updated.toDate()));
            final fromUser = data['from'];
            return Card(
              elevation: 10,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ListTile(
                leading: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(fromUser).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const CircleAvatar(
                        backgroundImage: AssetImage('assets/images/avatars/avatar_placeholder.png'),
                      );
                    }

                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    final pseudo = userData['pseudo'] ?? 'Utilisateur';
                    final avatar = userData['avatar'] ?? 'avatar_placeholder.png';

                    return CircleAvatar(
                      backgroundImage: AssetImage('assets/images/avatars/$avatar'),
                    );
                  },
                ),
                title: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(fromUser).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Text('Utilisateur');
                    }

                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    final pseudo = userData['pseudo'] ?? 'Utilisateur';

                    return Text(
                      '$pseudo',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    );
                  },
                ),
                subtitle: const Text('a envoyé un duel'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUnread)
                      const Icon(Icons.fiber_new, color: Colors.red, size: 20),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () async {
                      final selectedDomains = await Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => OpponentDomainSelectionScreen(
                            key: UniqueKey(),
                            initialDomains: List<String>.from(data['domainesEnvoyeur'] ?? []),
                            duelId: request.id,
                            duelData: Map<String, dynamic>.from(data),
                          ),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            final tween = Tween(begin: 0.0, end: 1.0);
                            return FadeTransition(
                              opacity: animation.drive(tween),
                              child: child,
                            );
                          },
                        ),
                      );

                        if (selectedDomains != null && selectedDomains is List<String> && selectedDomains.length == 6) {
                          await FirebaseFirestore.instance
                              .collection('duels')
                              .doc(request.id)
                              .update({
                                'domainesReceveur': selectedDomains,
                                'status': 'accepted',
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Duel accepté avec sélection des domaines.")));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sélection annulée.")));
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('duels')
                            .doc(request.id)
                            .delete();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Duel supprimé.")));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class HistoryDuelsWidget extends StatefulWidget {
  final ValueChanged<int> onUnreadCount;
  const HistoryDuelsWidget({Key? key, required this.onUnreadCount}) : super(key: key);

  @override
  State<HistoryDuelsWidget> createState() => _HistoryDuelsWidgetState();
}

class _HistoryDuelsWidgetState extends State<HistoryDuelsWidget> {
  String? myAvatar;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      getUserAvatar(uid).then((a) => setState(() => myAvatar = a));
    }
  }
  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final query = FirebaseFirestore.instance
        .collection('duels')
        .where('status', isEqualTo: 'accepted')
        .where('participants', arrayContains: currentUser?.uid)
        .orderBy('createdAt', descending: true)
        .limit(20);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final total = (data['questions'] as List?)?.length ?? 0;
          if (total == 0) return false;
          final current1 = data['player1']?['currentIndex'] ?? 0;
          final current2 = data['player2']?['currentIndex'] ?? 0;
          return current1 >= total && current2 >= total;
        }).toList();
        final uid = currentUser?.uid;
        final unread = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final updated = data['updatedAt'] as Timestamp?;
          final opened = uid != null ? data['lastOpened_$uid'] as Timestamp? : null;
          return updated != null && (opened == null || opened.toDate().isBefore(updated.toDate()));
        }).length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onUnreadCount(unread);
        });

        if (docs.isEmpty) return const Center(child: Text("Aucun duel terminé pour le moment."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final duel = docs[index];
            final data = duel.data() as Map<String, dynamic>;
            final updated = data['updatedAt'] as Timestamp?;
            final opened = uid != null ? data['lastOpened_$uid'] as Timestamp? : null;
            final isUnread = updated != null && (opened == null || opened.toDate().isBefore(updated.toDate()));
            final opponentUid = data['from'] == currentUser?.uid
                ? (data['player2']?['uid'] ?? '')
                : (data['player1']?['uid'] ?? '');
            final opponent = data['from'] == currentUser?.uid
                ? (data['player2']?['pseudo'] ?? 'Adversaire inconnu')
                : (data['player1']?['pseudo'] ?? 'Adversaire inconnu');
            final score1 = data['player1']?['score'] ?? 0;
            final score2 = data['player2']?['score'] ?? 0;
            String resultText;
            if (score1 == score2) {
              resultText = "Égalité";
            } else if ((data['from'] == currentUser?.uid && score1 > score2) ||
                (data['to'] == currentUser?.uid && score2 > score1)) {
              resultText = "Victoire";
            } else {
              resultText = "Défaite";
            }

            return Card(
              elevation: 10,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ListTile(
                leading: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(opponentUid).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const CircleAvatar(
                        radius: 32,
                        backgroundImage: AssetImage('assets/images/avatars/avatar_placeholder.png'),
                      );
                    }
                    final opponentAvatar = (snapshot.data!.data() as Map<String, dynamic>)['avatar'];

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: myAvatar != null
                              ? AssetImage('assets/images/avatars/$myAvatar')
                              : const AssetImage('assets/images/avatars/avatar_placeholder.png'),
                        ),
                        const SizedBox(width: 4),
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: opponentAvatar != null
                              ? AssetImage("assets/images/avatars/$opponentAvatar")
                              : const AssetImage('assets/images/avatars/avatar_placeholder.png'),
                        ),
                      ],
                    );
                  },
                ),
                title: Text(' $opponent',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87),
                ),
                subtitle: Text(resultText),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUnread)
                      const Icon(Icons.fiber_new, color: Colors.red, size: 20),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.deepPurpleAccent),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DuelResultScreen(duelId: duel.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
