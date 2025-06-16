import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'classement_general_screen.dart';
import 'classement_hebdo_screen.dart';
import 'classement_comparatif_screen.dart';
import 'classement_perso_screen.dart';
import 'package:lottie/lottie.dart';

class AnimatedMenuButton extends StatefulWidget {
  final String title;
  final Widget target;

  const AnimatedMenuButton({required this.title, required this.target});

  @override
  State<AnimatedMenuButton> createState() => _AnimatedMenuButtonState();
}

class _AnimatedMenuButtonState extends State<AnimatedMenuButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500 + (widget.title.hashCode % 1000)),
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
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => widget.target));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/boiscartoon.png'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
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

class ClassementScreen extends StatefulWidget {
  const ClassementScreen({Key? key}) : super(key: key);

  @override
  _ClassementScreenState createState() => _ClassementScreenState();
}

class _ClassementScreenState extends State<ClassementScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
        'assets/videos/ClassementVideo_compressed.mp4')
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.play();
        setState(() {});
      });
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
                image: AssetImage('assets/images/classementbackground.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (_controller.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    AnimatedMenuButton(
                      title: "Classement Général",
                      target: ClassementGeneralScreen(),
                    ),
                    AnimatedMenuButton(
                      title: "Classement Hebdomadaire",
                      target: ClassementHebdoScreen(),
                    ),
                    AnimatedMenuButton(
                      title: "Mes Statistiques",
                      target: ClassementPersoScreen(),
                    ),
                    SizedBox(height: 90),
                  ],
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: SizedBox(
                    height: 120,
                    width: 120,
                    child: Lottie.asset(
                      'assets/lottie/sun3.json',
                      repeat: true,
                    ),
                  ),
                ),
                Positioned(
                  top: 36,
                  left: 36,
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
        ],
      ),
    );
  }
}
