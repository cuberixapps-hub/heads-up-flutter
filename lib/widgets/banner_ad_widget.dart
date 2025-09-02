import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../constants/app_theme.dart';

/// A reusable banner ad widget that displays Google AdMob banner ads
class BannerAdWidget extends StatefulWidget {
  final EdgeInsets padding;
  final Color? backgroundColor;
  final String widgetKey;

  const BannerAdWidget({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.backgroundColor,
    required this.widgetKey, // Unique key to identify this banner instance
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  final AdService _adService = AdService();
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adService.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerAdReady = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'Banner ad failed to load for ${widget.widgetKey}: $error',
          );
          ad.dispose();
          _bannerAd = null;
          _isBannerAdReady = false;

          // Retry after delay
          if (mounted) {
            Future.delayed(const Duration(seconds: 30), () {
              if (mounted) _loadBannerAd();
            });
          }
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBannerAdReady || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color:
          widget.backgroundColor ??
          (isDark
              ? Colors.black.withOpacity(0.8)
              : Colors.white.withOpacity(0.9)),
      padding: widget.padding,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: Container(
            alignment: Alignment.center,
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      ),
    );
  }
}

/// A widget that shows a banner ad at the bottom of a screen
class BottomBannerAd extends StatelessWidget {
  final Widget child;
  final bool showAd;
  final String widgetKey;

  const BottomBannerAd({
    super.key,
    required this.child,
    required this.widgetKey,
    this.showAd = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        if (showAd)
          BannerAdWidget(
            widgetKey: widgetKey,
            backgroundColor: AppTheme.backgroundColor,
            padding: const EdgeInsets.only(top: 8),
          ),
      ],
    );
  }
}

/// Helper widget to wrap entire screens with banner ads
class ScreenWithBannerAd extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final String screenName;
  final EdgeInsets bannerPadding;

  const ScreenWithBannerAd({
    super.key,
    required this.body,
    required this.screenName,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.bannerPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: Column(
        children: [
          Expanded(child: body),
          BannerAdWidget(
            widgetKey: '${screenName}_banner',
            padding: bannerPadding,
          ),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
