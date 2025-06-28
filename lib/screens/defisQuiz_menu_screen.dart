import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '/screens/quiz_screen.dart';
import '/screens/defis_screens/defi_quiz_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/screens/home_screen.dart';
import 'package:video_player/video_player.dart';

class _AnimatedFloatingButton extends StatefulWidget {
  final String text;
  final String backgroundImage;
  final VoidCallback onTap;
  final int glands;
  final int price;

  const _AnimatedFloatingButton({
    required this.text,
    required this.backgroundImage,
    required this.onTap,
    required this.glands,
    required this.price,
  });

  @override
  State<_AnimatedFloatingButton> createState() => _AnimatedFloatingButtonState();
}

class _AnimatedFloatingButtonState extends State<_AnimatedFloatingButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Image.asset(
        'assets/images/cumincia.png',
        height: 90,
      ),
    );
  }
}

class ChallengeScreen extends StatefulWidget {
  @override
  _ChallengeScreenState createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> with SingleTickerProviderStateMixin {
  int _glands = 0;
  bool _loading = true;
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;
  bool _animationsReady = false;

  @override
  void initState() {
    super.initState();
    _loadUserGlands();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.995, end: 1.005).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _animationsReady = true;

    _videoController = VideoPlayerController.asset('assets/videos/DefiQuizVideo.mp4')
      ..initialize().then((_) {
        _videoController.setVolume(0.0);
        _videoController.setLooping(true);
        _videoController.play();
        _isVideoInitialized = true;
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    if (_animationsReady) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _loadUserGlands() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null && data.containsKey('glands')) {
        setState(() {
          _glands = data['glands'];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _isVideoInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/paysagedefi.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
          ),
          // UI par-dessus
          ...buildChallengeUI(context),
          Positioned(
            top: 70,
            right: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/images/petitencart.png',
                  height: 40,
                ),
                Positioned(
                  right: 16,
                  child: Row(
                    children: [
                      Text(
                        '$_glands',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(1, 1))],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Image.asset('assets/images/gland.png', height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> buildChallengeUI(BuildContext context) {
    return [
      Positioned(
        top: 60,
        left: 20,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            SizedBox(
              height: 120,
              width: 120,
              child: Lottie.asset('assets/lottie/sun3.json', repeat: true),
            ),
            Positioned(
              top: 26,
              left: 26,
              child: IconButton(
                icon: Icon(Icons.home, color: Colors.white70, size: 50),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => HomeScreen(user: FirebaseAuth.instance.currentUser)),
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      Positioned(
        bottom: 120,
        left: 0,
        right: 0,
        child: _AnimatedFloatingButton(
          backgroundImage: 'assets/images/boiscartoon.png',
          onTap: () async {
            if (_glands >= 12) {
              final user = FirebaseAuth.instance.currentUser;
              final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
              await userRef.update({'glands': _glands - 12});
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryQuizScreen()),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Tu n’as pas assez de glands pour participer.")),
              );
            }
          },
          text: "Défi Quiz",
          glands: _glands,
          price: 12,
        ),
      ),
      _animationsReady
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Positioned(
                  top: 160,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: Offset(0, _animation.value),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: 1,
                        child: Image.asset(
                          'assets/images/defiquiz.png',
                          height: 290,
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          : Positioned(
              top: 160,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: 1,
                child: Image.asset(
                  'assets/images/defiquiz.png',
                  height: 290,
                ),
              ),
            ),
      Positioned(
        bottom: 50,
        left: 0,
        right: 0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/petitencart.png',
              height: 40,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  ' ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(1, 1))],
                  ),
                ),
                Text(
                  '12',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(1, 1))],
                  ),
                ),
                const SizedBox(width: 4),
                Image.asset('assets/images/gland.png', height: 22),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // ✅ Navigation vers un quiz de la catégorie choisie
  void _startQuiz(BuildContext context, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(category: category),
      ),
    );
  }
}
