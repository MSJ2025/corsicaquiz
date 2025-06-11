import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/screens/home_screen.dart';
import '/screens/quiz_screen.dart';
import '/screens/defis_screens/defi_quiz_screen.dart';
import '/screens/classic_quiz/classic_histoire_quiz_screen.dart';
import '/screens/classic_quiz/classic_culture_quiz_screen.dart';
import '/screens/classic_quiz/classic_faune_quiz_screen.dart';
import '/screens/classic_quiz/classic_personnalites_quiz_screen.dart';
import '/screens/classic_quiz/classic_geographie_quiz_screen.dart';

class _AnimatedFloatingButton extends StatefulWidget {
  final String text;
  final String backgroundImage;
  final VoidCallback onTap;

  const _AnimatedFloatingButton({
    required this.text,
    required this.backgroundImage,
    required this.onTap,
  });

  @override
  State<_AnimatedFloatingButton> createState() => _AnimatedFloatingButtonState();
}

class _AnimatedFloatingButtonState extends State<_AnimatedFloatingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    final duration = Duration(seconds: (2 + widget.text.hashCode % 3));
    _controller = AnimationController(vsync: this, duration: duration)..repeat(reverse: true);

    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(begin: 0.995, end: 1.005).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
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
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                height: 65,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: AssetImage(widget.backgroundImage),
                    fit: BoxFit.cover,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black45,
                        offset: Offset(1, 1),
                      ),
                    ],
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

class ClassicQuizMenuScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue,Colors.white, Colors.green.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Top Lottie animation
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Lottie.asset('assets/lottie/clouds.json', height: 200),
            ),
            // Top-left sun animation with home button
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
                      icon: Icon(Icons.home, color: Colors.white70, size: 50),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => HomeScreen(user: FirebaseAuth.instance.currentUser!)),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Bottom static image
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/murcartoon.png',
                fit: BoxFit.cover,
                height: 300,
              ),
            ),
            // Game mode buttons
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 10), // Espace pour le notch
                _AnimatedFloatingButton(
                  backgroundImage: 'assets/images/boiscartoon.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ClassicHistoireQuizScreen()),
                    );
                  },
                  text: "Histoire",
                ),
                _AnimatedFloatingButton(
                  backgroundImage: 'assets/images/boiscartoon.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ClassicGeographieQuizScreen()),
                    );
                  },
                  text: "Géographie",
                ),
                _AnimatedFloatingButton(
                  backgroundImage: 'assets/images/boiscartoon.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ClassicCultureQuizScreen()),
                    );
                  },
                  text: "Gastronomie, Culture & Traditions",
                ),
                _AnimatedFloatingButton(
                  backgroundImage: 'assets/images/boiscartoon.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ClassicFauneQuizScreen()),
                    );
                  },
                  text: "Faune & Flore",
                ),
                _AnimatedFloatingButton(
                  backgroundImage: 'assets/images/boiscartoon.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ClassicPersonnalitesQuizScreen()),
                    );
                  },
                  text: "Personnalités",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Navigation vers un quiz de la catégorie choisie
  void _startQuiz(BuildContext context, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(category: category), // 🔹 Redirige vers QuizScreen
      ),
    );
  }
}
