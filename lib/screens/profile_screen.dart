import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import '../services/profile_service.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  ProfileScreen({required this.user});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final TextEditingController _pseudoController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  String _selectedAvatar = "1.png";
  int _points = 0;
  int _glands = 0;
  int _totalWins = 0;
  int _totalLosses = 0;
  bool _loading = true;
  bool _incognito = false;
  bool _checkingPseudo = false;
  String? _pseudoError;
  bool _showAvatarGrid = false;

  @override
  void initState() {
    super.initState();
    _loadProfileStats();
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get()
        .then((doc) {
      if (doc.exists && doc.data()!.containsKey('incognito')) {
        setState(() => _incognito = doc.data()!['incognito'] == true);
      }
    });
  }

  Future<void> _loadProfileStats() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _points         = (data['points'] is int)     ? data['points']     : 0;
        _glands         = (data['glands'] is int)     ? data['glands']     : 0;
        _totalWins      = (data['totalWins'] is int)  ? data['totalWins']  : 0;
        _totalLosses    = (data['totalLosses'] is int) ? data['totalLosses'] : 0;
        _selectedAvatar = data['avatar'] ?? "1.png";
        _pseudoController.text = data['pseudo'] ?? '';
        _bioController.text    = data['bio']    ?? '';
        _loading        = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_checkingPseudo) return;

    setState(() {
      _checkingPseudo = true;
      _pseudoError    = null;
    });

    final pseudo = _pseudoController.text.trim();
    final bio    = _bioController.text.trim();

    if (pseudo.length > 16) {
      setState(() {
        _checkingPseudo = false;
        _pseudoError = "Le pseudo ne doit pas dépasser 16 caractères";
      });
      return;
    }

    if (pseudo.isEmpty) {
      setState(() => _checkingPseudo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Le pseudo est obligatoire")),
      );
      return;
    }

    bool taken;
    try {
      taken = await _profileService.isPseudoTaken(
        pseudo,
        excludeUid: widget.user.uid,
      );
    } catch (e) {
      setState(() => _checkingPseudo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la vérification du pseudo")),
      );
      return;
    }

    if (taken) {
      setState(() {
        _pseudoError    = "Ce pseudo est déjà utilisé";
        _checkingPseudo = false;
      });
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid);
    final docSnapshot = await docRef.get();

    final data = {
      "pseudo":    pseudo,
      "avatar":    _selectedAvatar,
      "bio":       bio,
      "incognito": _incognito,
    };

    if (docSnapshot.exists) {
      await docRef.update(data);
    } else {
      await docRef.set({
        "uid":                 widget.user.uid,
        ...data,
        "score_total":         0,
        "classement":          0,
        "quiz_joues":          0,
        "precision":           0.0,
        "temps_reponse_moyen": 0.0,
        "points":              0,
        "glands":              0,
      });
    }

    setState(() => _checkingPseudo = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(user: widget.user)),
    );
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  double _successRate() {
    final total = _totalWins + _totalLosses;
    if (total == 0) return 0.0;
    return _totalWins / total;
  }

  int _duelsJoues() {
    return _totalWins + _totalLosses;
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
    Widget? customIcon,
  }) {
    return Card(
      color: Colors.white,
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 18),
        child: Row(
          children: [
            if (customIcon != null)
              customIcon
            else if (icon != null)
              Icon(icon, color: iconColor ?? Colors.blue, size: 32),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showAvatarGrid = !_showAvatarGrid),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundImage: AssetImage(
                  'assets/images/avatars/${_selectedAvatar.isNotEmpty ? _selectedAvatar : '1.png'}',
                ),
              ),
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent,
                ),
                child: Icon(Icons.edit, size: 18, color: Colors.white),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        AnimatedCrossFade(
          duration: Duration(milliseconds: 300),
          crossFadeState: _showAvatarGrid ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              physics: NeverScrollableScrollPhysics(),
              children: List.generate(29, (index) {
                final avatarFile = "${index + 1}.png";
                final isSelected = _selectedAvatar == avatarFile;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedAvatar = avatarFile;
                    _showAvatarGrid = false;
                  }),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    padding: EdgeInsets.all(isSelected ? 2 : 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.orangeAccent : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.orangeAccent.withOpacity(0.5), blurRadius: 6)]
                          : [],
                    ),
                    child: CircleAvatar(
                      backgroundImage: AssetImage('assets/images/avatars/$avatarFile'),
                      radius: 30,
                    ),
                  ),
                );
              }),
            ),
          ),
          secondChild: SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildInputCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorText,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 2),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        child: TextField(
          controller: controller,
          style: TextStyle(color: Colors.black87, fontSize: 16),
          maxLength: label == "Pseudo" ? 16 : null,
          decoration: InputDecoration(
            icon: Icon(icon, color: Colors.blueGrey[600]),
            labelText: label,
            labelStyle: TextStyle(color: Colors.blueGrey[600]),
            border: InputBorder.none,
            errorText: errorText,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _checkingPseudo ? null : _saveProfile,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade600, Colors.deepOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
          ],
        ),
        child: _checkingPseudo
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    "Enregistrer",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Secure access to 'online' field
        final docData = snapshot.data?.data();
        final isOnline = (docData is Map<String, dynamic> && docData.containsKey('online'))
            ? docData['online'] == true
            : false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 500),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isOnline ? Colors.greenAccent : Colors.grey,
                shape: BoxShape.circle,
                boxShadow: isOnline
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.6),
                          spreadRadius: 3,
                          blurRadius: 6,
                        )
                      ]
                    : [],
              ),
            ),
            SizedBox(width: 8),
            Text(
              isOnline ? "Connecté" : "Hors ligne",
              style: TextStyle(
                color: isOnline ? Colors.green : Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIncognitoToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _incognito = !_incognito);
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .update({
          "incognito": _incognito,
          "online": !_incognito,
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _incognito ? Colors.redAccent : Colors.green,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _incognito ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              _incognito
                  ? "Mode incognito activé"
                  : "Visible en ligne",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars() {
    int starCount = 1;
    if (_points >= 1000) starCount = 2;
    if (_points >= 5000) starCount = 3;
    if (_points >= 20000) starCount = 4;
    if (_points >= 40000) starCount = 5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        starCount,
        (index) => Icon(Icons.star, color: Colors.amber, size: 26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Decorative background (preserve fade, gradient, etc.)
          Opacity(opacity: 0.17, child: Container(color: Colors.blue)),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade900, Colors.white, Colors.yellow.shade100],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 78),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FadeIn(
                      duration: Duration(milliseconds: 900),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6))],
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar selector
                              _buildAvatarSelector(),
                              SizedBox(height: 8),
                              // Pseudo (input)
                              _buildInputCard(
                                controller: _pseudoController,
                                label: "Pseudo",
                                icon: Icons.person,
                                errorText: _pseudoError,
                              ),
                              // Bio (input)
                              // _buildInputCard(
                              //   controller: _bioController,
                              //   label: "Bio (optionnel)",
                              //   icon: Icons.edit,
                              // ),
                              SizedBox(height: 6),
                              // Stars
                              _buildStars(),
                              SizedBox(height: 8),
                              // Status row
                              _buildStatusRow(),
                              SizedBox(height: 8),
                              // Incognito toggle
                              _buildIncognitoToggle(),
                              SizedBox(height: 12),
                              // Save button
                              _buildSaveButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_loading)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(),
                      ),
                    if (!_loading)
                      FadeIn(
                        duration: Duration(milliseconds: 350),
                        child: Column(
                          children: [
                            // Stat cards
                            _buildStatCard(
                              label: "Points totaux",
                              value: _points.toString(),
                              icon: Icons.stars,
                              iconColor: Colors.amber,
                            ),
                            _buildStatCard(
                              label: "Glands",
                              value: _glands.toString(),
                              customIcon: Image.asset('assets/images/gland.png', height: 32, width: 32),
                            ),
                            _buildStatCard(
                              label: "Victoires",
                              value: _totalWins.toString(),
                              icon: Icons.emoji_events,
                              iconColor: Colors.green.shade700,
                            ),
                            _buildStatCard(
                              label: "Duels joués",
                              value: "${_duelsJoues()}",
                              icon: Icons.sports_martial_arts,
                              iconColor: Colors.deepPurple,
                            ),
                            _buildStatCard(
                              label: "Taux de victoires",
                              value: "${(_successRate() * 100).toStringAsFixed(1)} %",
                              icon: Icons.percent,
                              iconColor: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
