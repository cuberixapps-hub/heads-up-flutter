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
  AdSize? _adSize;

  @override
  void initState() {
    super.initState();
    // Only load banner ad if AdMob SDK is initialized
    if (AdService.isInitialized) {
      // Wait for the first frame to get context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBannerAd();
      });
    } else {
      // Try again after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && AdService.isInitialized) {
          _loadBannerAd();
        }
      });
    }
  }

  Future<void> _loadBannerAd() async {
    // Safety check
    if (!AdService.isInitialized) {
      debugPrint('⚠️ AdMob SDK not initialized yet for ${widget.widgetKey}');
      return;
    }

    // Get adaptive ad size based on screen width
    final screenWidth = MediaQuery.of(context).size.width.truncate();
    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
          screenWidth,
        );

    if (adSize == null) {
      debugPrint('❌ Could not get adaptive ad size');
      return;
    }

    setState(() {
      _adSize = adSize;
    });

    _bannerAd = BannerAd(
      adUnitId: _adService.bannerAdUnitId,
      request: const AdRequest(),
      size: adSize,
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload ad when orientation changes
    final currentWidth = MediaQuery.of(context).size.width.truncate();

    // Check if we need to reload the ad due to orientation change
    if (_bannerAd != null && _adSize != null) {
      final needsReload = _adSize!.width != currentWidth;
      if (needsReload) {
        debugPrint('🔄 Reloading banner ad due to orientation change');
        _bannerAd?.dispose();
        _bannerAd = null;
        _isBannerAdReady = false;
        _loadBannerAd();
      }
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBannerAdReady || _bannerAd == null || _adSize == null) {
      // Return a placeholder with the expected height to prevent layout jumps
      return Container(
        width: double.infinity,
        height: 60, // Approximate height for adaptive banners
        color: Colors.transparent,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity, // Ensure full width
      color:
          widget.backgroundColor ??
          (isDark
              ? Colors.black.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.9)),
      padding: widget.padding,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          alignment: Alignment.center,
          width: double.infinity, // Full width
          height: _adSize!.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
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
          SizedBox(
            width: double.infinity, // Ensure full width
            child: BannerAdWidget(
              widgetKey: '${screenName}_banner',
              padding: bannerPadding,
            ),
          ),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
