// lib/services/reklam_servisi.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ReklamServisi {
  static final ReklamServisi _instance = ReklamServisi._internal();
  factory ReklamServisi() => _instance;
  ReklamServisi._internal();

  BannerAd? _bannerAd;
  bool _bannerYuklendi = false;

  void bannerYukle({VoidCallback? onYuklendi}) {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3219214594050063/2886208975',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _bannerYuklendi = true;
          onYuklendi?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerYuklendi = false;
        },
      ),
    )..load();
  }

  Widget? bannerWidget() {
    if (!_bannerYuklendi || _bannerAd == null) return null;
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  void dispose() {
    _bannerAd?.dispose();
  }
}