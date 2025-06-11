import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'classement_perso_screen.dart';

class ClassementComparatifScreen extends StatefulWidget {
  const ClassementComparatifScreen({Key? key}) : super(key: key);

  @override
  State<ClassementComparatifScreen> createState() => _ClassementComparatifScreenState();
}

class _ClassementComparatifScreenState extends State<ClassementComparatifScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  Map<String, int> winsByOpponent = {};
  Map<String, int> duelsByOpponent = {};
  Map<String, dynamic> opponentInfos = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    final data = doc.data() ?? {};

    winsByOpponent = Map<String, int>.from(data['winsByOpponent'] ?? {});
    duelsByOpponent = Map<String, int>.from(data['duelsByOpponent'] ?? {});

    final opponentIds = {...winsByOpponent.keys, ...duelsByOpponent.keys}.toList();
    for (String uid in opponentIds) {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (snapshot.exists) {
        opponentInfos[uid] = snapshot.data();
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final allOpponents = {...winsByOpponent.keys, ...duelsByOpponent.keys}.toList();

    allOpponents.sort((a, b) {
      final totalA = duelsByOpponent[a] ?? (winsByOpponent[a] ?? 0);
      final totalB = duelsByOpponent[b] ?? (winsByOpponent[b] ?? 0);
      return totalB.compareTo(totalA);
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Comparaison des duels'),
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
          allOpponents.isEmpty
              ? const Center(child: Text('Aucun duel enregistré.', style: TextStyle(color: Colors.white)))
              : ListView.builder(
                  itemCount: allOpponents.length,
                  itemBuilder: (context, index) {
                    final uid = allOpponents[index];
                    final pseudo = opponentInfos[uid]?['pseudo'] ?? 'Adversaire';
                    final avatar = opponentInfos[uid]?['avatar'] ?? '1.png';
                    final wins = winsByOpponent[uid] ?? 0;
                    final total = duelsByOpponent[uid] ?? wins;
                    final losses = total - wins;

                    final color = wins > losses
                        ? Colors.green.withOpacity(0.7)
                        : (losses > wins ? Colors.red.withOpacity(0.7) : Colors.blue.shade600.withOpacity(0.6));

                    return Card(
                      color: color,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClassementPersoScreen(userId: uid),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            backgroundImage: AssetImage('assets/images/avatars/$avatar'),
                          ),
                        ),
                        title: Text(pseudo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(
                          '     Duels: $total •      Victoires: $wins •      Défaites: $losses',
                          style: const TextStyle(color: Colors.white,fontSize: 12, fontWeight: FontWeight.bold ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
