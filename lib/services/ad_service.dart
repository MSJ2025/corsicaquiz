import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';

class AdService {
  static const String bannerTestId = 'ca-app-pub-3940256099942544/4411468910';

  static InterstitialAd? _interstitial;
  static bool _interstitialReady = false;

  static Future<void> init() async {
    await MobileAds.instance.initialize();
    loadInterstitial();
  }

  static void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: InterstitialAd.testAdUnitId,
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
    if (_interstitialReady && _interstitial != null) {
      _interstitial!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadInterstitial();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          loadInterstitial();
        },
      );
      _interstitial!.show();
      _interstitialReady = false;
    }
  }

  static BannerAd createBanner(VoidCallback onLoaded) {
    final banner = BannerAd(
      adUnitId: bannerTestId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onLoaded(),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    banner.load();
    return banner;
  }
}
