import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '/screens/home_screen.dart';
import 'duel_user_list_screen.dart';
import 'duel_dashboard_screen.dart';
import 'accepted_duels_screen.dart';
import '../favorites_screen.dart';


class DuelMenuScreen extends StatefulWidget {
  const DuelMenuScreen({Key? key}) : super(key: key);

  @override
  _DuelMenuScreenState createState() => _DuelMenuScreenState();
}

class _DuelMenuScreenState extends State<DuelMenuScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _animationController;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/RocherVideo.mp4')
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.play();
        setState(() {});
      });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scaleAnimation == null) {
      return const SizedBox.shrink();
    }
    return Scaffold(
      body: Stack(
        children: [
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
          Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _scaleAnimation ?? kAlwaysDismissedAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation?.value ?? 1.0,
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/images/duels.png',
                  height: 300,
                ),
              ),
            ),
          ),
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
          Positioned(
            top: 470,
            left: 0,
            right: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CustomButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DuelUserListScreen(),
                      ),
                    );
                  },
                  label: 'Trouver un adversaire',
                ),
                const SizedBox(height: 16),
                _CustomButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DuelDashboardScreen(),
                      ),
                    );
                  },
                  label: 'Duels à jouer',
                  backgroundColor: Colors.blueAccent,
                ),
                _CustomButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const FavoritesScreen()),
                    );
                  },
                  label: 'Mes favoris',
                  backgroundColor: Colors.blueAccent,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final Color backgroundColor;

  const _CustomButton({
    required this.onPressed,
    required this.label,
    this.backgroundColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: 57,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/boiscartoon.png'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 16),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
