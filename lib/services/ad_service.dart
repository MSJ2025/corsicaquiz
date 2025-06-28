import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class AdService {
  // Identifiant interstitiel de test pour Android
  // Remplacez-le par votre ID Android lors de la mise en production
  static const String _interstitialAndroidId =
      'ca-app-pub-4176691748354941/8784531479';

  // Identifiant interstitiel de test pour iOS
  // Remplacez-le par votre ID iOS lors de la mise en production
  static const String _interstitialIosId =
      'ca-app-pub-4176691748354941/7472014459';

  static InterstitialAd? _interstitial;
  // Indique si l'interstitiel est prêt à être affiché
  static bool _interstitialReady = false;

  static Future<void> init() async {
    await MobileAds.instance.initialize();
    // Charge un interstitiel dès le démarrage de l'application
    loadInterstitial();
  }

  static void loadInterstitial() {
    InterstitialAd.load(
      // Sélection de l'identifiant adapté à Android ou iOS
      adUnitId:
          Platform.isAndroid ? _interstitialAndroidId : _interstitialIosId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitialReady = true;
        },
        onAdFailedToLoad: (error) {
          _interstitialReady = false;
        },
      ),
    );
  }

  static void showInterstitial() {
    // Affiche l'interstitiel s'il est prêt
    if (_interstitialReady && _interstitial != null) {
      _interstitial!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          // Recharge automatiquement un interstitiel une fois l'affichage terminé
          ad.dispose();
          loadInterstitial();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          // En cas d'erreur d'affichage, on détruit l'instance
          // et on tente de recharger pour la prochaine fois
          ad.dispose();
          loadInterstitial();
        },
      );
      _interstitial!.show();
      // L'interstitiel ne peut être réutilisé, on marque donc l'état comme non prêt
      _interstitialReady = false;
    }
  }

  // La gestion des bannières publicitaires a été supprimée
  // car l'application n'en affiche pas.
}
