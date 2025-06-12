import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'dart:io';
import '/services/profile_service.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '/services/ad_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class LoginScreen extends StatefulWidget {
  final AuthService? authService;

  const LoginScreen({Key? key, this.authService}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _authService;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false; // Indicateur de chargement
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _bannerAd = AdService.createBanner(() {
      setState(() {
        _bannerLoaded = true;
      });
    });
  }

  void _handleAuth() async {
    setState(() => _isLoading = true);

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Veuillez remplir tous les champs")),
      );
      setState(() => _isLoading = false);
      return;
    }

    User? user;
    user = await _authService.signInWithEmail(email, password);

    setState(() => _isLoading = false);

    if (user != null) {
      bool hasProfile = await ProfileService().hasProfile(user.uid);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => hasProfile
              ? HomeScreen(user: user!)
              : ProfileScreen(user: user!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur d'authentification")),
      );
    }
  }

  void _showSignupDialog() {
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController passCtrl = TextEditingController();
    final TextEditingController confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: const [
                    Icon(Icons.person_add_alt_1, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Créer un compte",
                      style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(emailCtrl, "Email", Icons.email, false),
                const SizedBox(height: 10),
                _buildTextField(passCtrl, "Mot de passe", Icons.lock, true),
                const SizedBox(height: 10),
                _buildTextField(confirmCtrl, "Confirmer le mot de passe", Icons.lock_outline, true),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: const Text("Annuler", style: TextStyle(color: Colors.white70)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("S'inscrire"),
                      onPressed: () async {
                        String email = emailCtrl.text.trim();
                        String pass = passCtrl.text.trim();
                        String confirm = confirmCtrl.text.trim();

                        if (pass != confirm) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Les mots de passe ne correspondent pas"),
                          ));
                          return;
                        }

                        Navigator.pop(context);
                        setState(() => _isLoading = true);

                        User? user = await _authService.signUpWithEmail(email, pass);
                        setState(() => _isLoading = false);

                        if (user != null) {
                          bool hasProfile = await ProfileService().hasProfile(user.uid);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => hasProfile
                                  ? HomeScreen(user: user)
                                  : ProfileScreen(user: user),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Erreur lors de l'inscription"),
                          ));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ Nouveau bouton avec un design premium
  Widget _buildAuthButton() {
    return GestureDetector(
      onTap: _handleAuth,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], // Dégradé bleu-violet
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: _isLoading
                ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : Text(
              "Connexion",
              key: ValueKey("Connexion"), // Anime le texte au changement
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1E2C), Color(0xFF2A2A42)], // Dégradé sombre moderne
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔹 Logo de l'application
                Hero(
                  tag: 'logo',
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 200,
                  ),
                ),
                SizedBox(height: 20),

                // 🔹 Champ Email
                _buildTextField(_emailController, "Email", Icons.email, false),
                SizedBox(height: 05),

                // 🔹 Champ Mot de passe
                _buildTextField(_passwordController, "Mot de passe", Icons.lock, true),

                SizedBox(height: 20),

                // 🔹 Bouton Connexion/Inscription
                _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : _buildAuthButton(),

                // 🔹 Lien pour basculer entre Connexion/Inscription
                TextButton(
                  onPressed: _showSignupDialog,
                  child: Text(
                    "Créer un compte",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                SizedBox(height: 20),

                // 🔹 Bouton Google
                _buildSocialButton(
                  onTap: () async {
                    User? user = await _authService.signInWithGoogle();
                    if (user != null) {
                      bool hasProfile = await ProfileService().hasProfile(user.uid);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => hasProfile
                              ? HomeScreen(user: user)
                              : ProfileScreen(user: user),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Échec de la connexion')),
                      );
                    }
                  },
                  icon: "assets/icons/google.png",
                  text: "Se connecter avec Google",
                ),

                // 🔹 Bouton Apple (uniquement sur iOS)
                if (Platform.isIOS)
                  _buildSocialButton(
                    onTap: () async {
                      User? user = await _authService.signInWithApple();
                      if (user != null) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => HomeScreen(user: user)),
                        );
                      }
                    },
                    icon: "assets/icons/apple.png",
                    text: "Se connecter avec Apple",
                  ),

                SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        backgroundColor: Color(0xFF1E1E2C),
                        title: Text("Conditions Générales d'Utilisation", style: TextStyle(color: Colors.yellowAccent)),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("1. Objectif", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                              Text("L’application Corsica Quiz propose des jeux de culture générale sur la Corse. Elle permet à l’utilisateur de participer à différents types de quiz et de consulter des classements.\n\n", style: TextStyle(color: Colors.white70)),
                              Text("2. Compte utilisateur", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                              Text("L'utilisateur peut créer un compte via Google, Apple ou e-mail. Il peut le supprimer à tout moment, entraînant la suppression de ses données.\n\n", style: TextStyle(color: Colors.white70)),
                              Text("3. Données collectées", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                              Text("Adresse e-mail, pseudo, statistiques (Firebase), IP (Google Analytics).\n\n", style: TextStyle(color: Colors.white70)),
                              Text("4. Publicité", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                              Text("Publicités diffusées via Google AdMob, pouvant utiliser des données anonymes.\n\n", style: TextStyle(color: Colors.white70)),
                              Text("5. Analyse", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                              Text("Analyse anonyme via Google Analytics.\n\n", style: TextStyle(color: Colors.white70)),
                              Text("6. Suppression de données", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                              Text("L'utilisateur peut supprimer son compte à tout moment depuis l'application.\n\n", style: TextStyle(color: Colors.white70)),
                              Text("7. Contact", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                              Text("Pour toute demande : msj2025@icloud.com\n\n", style: TextStyle(color: Colors.white70)),
                              Text("8. Modifications", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                              Text("Les CGU peuvent être mises à jour. Les utilisateurs seront informés de toute modification majeure.", style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: Text("Fermer", style: TextStyle(color: Colors.white70)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    "Conditions d'utilisation",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _bannerLoaded && _bannerAd != null
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ✅ Widget pour un champ de texte stylisé
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ✅ Widget pour un bouton de connexion avec un service externe
  Widget _buildSocialButton({required VoidCallback onTap, required String icon, required String text}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(icon, height: 24), // Icône du service
            SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
