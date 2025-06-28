import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/profile_service.dart';
import '/services/winner_service.dart'; // Ajout de l'import pour WinnerService
import '/services/presence_service.dart';
import '/screens/home_screen.dart';
import '/screens/profile_screen.dart';
import 'package:upgrader/upgrader.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(Duration(seconds: 2));
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    if (user != null) {
      PresenceService().init(user.uid);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      upgrader: Upgrader(
        messages: UpgraderMessages(code: 'fr'),
        countryCode: 'FR',
        debugLogging: true,

      ),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/splash.png',
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ Animation du logo avec Flame

class SplashAnimationGame extends FlameGame {
  final BuildContext context;
  SplashAnimationGame(this.context);

  late SpriteComponent logo;

  @override
  Color backgroundColor() => Colors.transparent; // ✅ Force la transparence

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 🔹 Chargement du sprite du logo
    final sprite = await loadSprite('logo.png');

    logo = SpriteComponent()
      ..sprite = sprite
      ..size = Vector2(200, 200)
      ..position = size / 2
      ..anchor = Anchor.center
      ..opacity = 0; // Débute totalement transparent

    add(logo);

    // 🔹 Animation en fondu du logo
    logo.add(
      OpacityEffect.to(
        1, // Opacité 100%
        EffectController(duration: 2), // Animation en 2s
      ),
    );

  }
}
