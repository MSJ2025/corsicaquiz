import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '/screens/login_screen.dart';
import '/screens/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/screens/defisQuiz_menu_screen.dart';
import '/screens/classic_quiz/classic_quiz_menu_screen.dart';
import 'package:lottie/lottie.dart';
import '/screens/classic_quiz/classic_quiz_menu_screen.dart';
import '/screens/duel_screens/duel_menu_screen.dart';
import '/screens/classement/classement_screen.dart';
import '/screens/etude_questions.dart';
import 'signalements_questions_screen.dart';
import '/screens/proposition_question_screen.dart';
import '/screens/questions_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  double _boatX = 0.0;
  late AnimationController _settingsController;

  @override
  void initState() {
    super.initState();
    _settingsController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Fond dégradé classe de blancs
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.lightBlueAccent, Colors.white, Colors.yellow],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 🔹 Animation en haut
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 150,
              child: Lottie.asset(
                'assets/lottie/clouds.json',
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),
          ),

          // 🔹 Animation en bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 129,
              child: Lottie.asset(
                'assets/lottie/sea.json',
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),
          ),

          // 🔹 Animation du bateau sur la mer contrôlable
          Positioned(
            bottom: 30,
            left: MediaQuery.of(context).size.width / 2 - 50,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _boatX += details.delta.dx;
                });
              },
              child: AnimatedBuilder(
                animation: _settingsController,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(_boatX, 0),
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Lottie.asset(
                        'assets/lottie/boat.json',
                        repeat: true,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 🔹 Bouton de paramètres
          Positioned(
            top: 50,
            right: 20,
            child: AnimatedBuilder(
              animation: _settingsController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _settingsController.value * 2 * 3.1416,
                  child: child,
                );
              },
              child: IconButton(
                icon: Icon(Icons.settings, color: Colors.blueGrey, size: 40),
                onPressed: () {
                  _showSettingsModal(context);
                },
              ),
            ),
          ),

          // 🔹 Contenu principal
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 60), // Espace pour le notch

              // ✅ Profil utilisateur
              _buildUserProfile(context, widget.user),

              SizedBox(height: 20),

              // ✅ Modes de jeu
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 25,),
                      _buildGameModeButton(
                        context,
                        icon: Icons.play_arrow,
                        text: "Quiz Classique",
                        backgroundImage: 'assets/images/boiscartoon.png',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ClassicQuizMenuScreen()),
                          );
                        },
                      ),
                      SizedBox(height: 25),
                      _buildGameModeButton(
                        context,
                        icon: Icons.flash_on,
                        text: "Défis Quiz",
                        backgroundImage: 'assets/images/boiscartoon.png',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChallengeScreen()));
                        },
                      ),
                      SizedBox(height: 25),
                      _buildGameModeButton(
                        context,
                        icon: Icons.people,
                        text: "Duel en Ligne",
                        backgroundImage: 'assets/images/boiscartoon.png',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => DuelMenuScreen()));
                        },
                      ),
                      SizedBox(height: 25),
                      _buildGameModeButton(
                        context,
                        icon: Icons.leaderboard,
                        text: "Classement",
                        backgroundImage: 'assets/images/boiscartoon.png',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ClassementScreen()));
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text("Déconnexion"),
                onTap: () async {
                  await _authService.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
              ),
              // --- Supprimer mon compte ---
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.redAccent),
                title: Text("Supprimer mon compte"),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text("Confirmer la suppression"),
                      content: Text("Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible."),
                      actions: [
                        TextButton(
                          child: Text("Annuler"),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        TextButton(
                          child: Text("Supprimer", style: TextStyle(color: Colors.red)),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      final uid = widget.user.uid;
                      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
                      await widget.user.delete();
                      await _authService.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            backgroundColor: Colors.white,
                            body: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
                                  SizedBox(height: 20),
                                  Text(
                                    "Votre compte a été supprimé avec succès.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(height: 30),
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.login),
                                    label: Text("Retour à l'écran de connexion"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (_) => LoginScreen()),
                                      );
                                    },
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        (route) => false,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Erreur lors de la suppression du compte.")),
                      );
                    }
                  }
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.menu_book_rounded, color: Colors.blueAccent),
                title: Text("Étude des questions"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EtudeQuestionsScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: Colors.green),
                title: Text("Proposer une question"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PropositionQuestionScreen()),
                  );
                },
              ),
              if (widget.user.email == 'pacman93@gmail.com' ||
                  widget.user.email == 'alexandrejordan84@gmail.com' ||
                  widget.user.email == 'dev.msj2025@gmail.com') ...[
                Divider(),
                ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                  title: Text("Voir les signalements"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignalementsQuestionsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.lightbulb_outline, color: Colors.purple),
                  title: Text("Voir les propositions"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => QuestionsSelectionScreen()),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ✅ Widget pour l'affichage du profil utilisateur
  Widget _buildUserProfile(BuildContext context, User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return CircularProgressIndicator();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final pseudo = data['pseudo'] ?? "Utilisateur";
        final avatar = data['avatar'] ?? "1.png";
        final points = data['points'] ?? 0;
        final glands = data['glands'] ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen(user: user)),
            );
          },
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage("assets/images/avatars/$avatar"),
              ),
              SizedBox(height: 10),
              Text(
                pseudo,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Card(
                color: Colors.white.withOpacity(0.2),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars, color: Colors.yellow.shade700, size: 20),
                      SizedBox(width: 5),
                      Text(
                        "$points",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 15),
                      Image.asset('assets/images/gland.png', height: 20, width: 20),
                      SizedBox(width: 5),
                      Text(
                        "$glands",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ Widget pour les boutons des modes de jeu
  Widget _buildGameModeButton(
      BuildContext context, {
        required IconData icon,
        required String text,
        required String backgroundImage,
        required VoidCallback onTap,
      }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return _AnimatedFloatingButton(
          icon: icon,
          text: text,
          backgroundImage: backgroundImage,
          onTap: onTap,
        );
      },
    );
  }
}

class _AnimatedFloatingButton extends StatefulWidget {
  final IconData icon;
  final String text;
  final String backgroundImage;
  final VoidCallback onTap;

  const _AnimatedFloatingButton({
    required this.icon,
    required this.text,
    required this.backgroundImage,
    required this.onTap,
  });

  @override
  State<_AnimatedFloatingButton> createState() => _AnimatedFloatingButtonState();
}

class _AnimatedFloatingButtonState extends State<_AnimatedFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    int variation = 2 + (widget.text.hashCode % 3);
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500 + (widget.text.hashCode % 1000)),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: -0.010, end: 0.010).animate(
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  height: 70,
                  margin: EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    image: DecorationImage(
                      image: AssetImage(widget.backgroundImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.icon, size: 30, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          widget.text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
