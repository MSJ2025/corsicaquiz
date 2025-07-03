import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'firebase_options.dart';
import '/screens/splash_screen.dart'; // Import du splash screen
import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/winner_service.dart';
import 'services/notification_service.dart';
import 'services/ad_service.dart';
import 'services/background_music_service.dart';
import 'theme_notifier.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await NotificationService.init();
  await ThemeNotifier.loadTheme();
  await AppTrackingTransparency.requestTrackingAuthorization();
  await AdService.init();
  BackgroundMusicService.instance.play();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.theme,
      builder: (context, mode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
          home: SplashScreen(),
        );
      },
    );
  }
}
