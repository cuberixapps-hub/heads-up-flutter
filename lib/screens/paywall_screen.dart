import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../services/ad_service.dart';
import '../services/firebase_service.dart';
import '../services/haptic_service.dart';
import '../services/purchases_service.dart';
import '../utils/responsive.dart';

const String _termsOfServiceUrl = 'https://heads-up-game-48f14.web.app/terms';
const String _privacyPolicyUrl = 'https://heads-up-game-48f14.web.app/privacy';

class PaywallScreen extends StatefulWidget {
  final Deck selectedDeck;
  final VoidCallback onWatchAd;
  final VoidCallback onPurchasePremium;
  final VoidCallback onClose;

  const PaywallScreen({
    super.key,
    required this.selectedDeck,
    required this.onWatchAd,
    required this.onPurchasePremium,
    required this.onClose,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with TickerProviderStateMixin {
  final HapticService _hapticService = HapticService();
  final AdService _adService = AdService();
  final PurchasesService _purchasesService = PurchasesService();

  // State for ad loading
  bool _isLoadingAd = false;

  // State for daily ad limit tracking
  bool _canWatchAd = true;
  int _remainingAdsToday = AdService.maxDailyRewardedAds;
  bool _isPremiumOnlyDeck = false;
  bool _isCustomDeck = false;

  // State for purchases
  bool _isLoadingPurchase = false;
  bool _isLoadingOfferings = true;
  Package? _selectedPackage;
  List<Package> _availablePackages = [];
  String _selectedPlanType = 'yearly';

  // Free trial info from the store product
  bool _yearlyHasFreeTrial = false;
  String _trialDurationText = '';
  String _trialBadgeText = '';

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // Scroll controller for auto-scroll to reveal weekend pass
  final ScrollController _scrollController = ScrollController();

  // Floating deck positions
  final List<_FloatingDeck> _floatingDecks = [];
  final List<_Sparkle> _sparkles = [];
  Timer? _deckAnimationTimer;
  Timer? _sparkleTimer;

  // Premium features - key benefits
  final List<_PremiumFeature> _premiumFeatures = [
    _PremiumFeature(
      icon: Icons.block_rounded,
      title: 'No Ads',
      color: const Color(0xFFE91E63),
    ),
    _PremiumFeature(
      icon: Icons.all_inclusive_rounded,
      title: 'All Decks',
      color: const Color(0xFF4CAF50),
    ),
    _PremiumFeature(
      icon: Icons.create_rounded,
      title: 'Custom Decks',
      color: const Color(0xFF2196F3),
    ),
    _PremiumFeature(
      icon: Icons.offline_bolt_rounded,
      title: 'Offline Play',
      color: const Color(0xFF9C27B0),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // Check if this is a custom deck created by the user (subscription required, no ads)
    _isCustomDeck = widget.selectedDeck.isCustom;

    // Check if this is a premium-only deck (no ads allowed)
    // Custom decks also require premium — ads are not available for them
    _isPremiumOnlyDeck = widget.selectedDeck.premiumOnly || _isCustomDeck;

    // Initialize floating decks and sparkles after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFloatingDecks();
      _initializeSparkles();
      _loadOfferings();
      _loadAdAvailability();
      // Preload rewarded ad as soon as paywall opens so it's ready when user taps
      if (!_isPremiumOnlyDeck && !_adService.isRewardedAdReady) {
        _adService.loadRewardedAd();
      }
    });

    // Log paywall viewed event
    FirebaseService().logEvent(
      'paywall_viewed',
      parameters: {
        'deck_id': widget.selectedDeck.id,
        'deck_name': widget.selectedDeck.name,
        'is_premium_deck': widget.selectedDeck.isPremium,
        'is_premium_only': widget.selectedDeck.premiumOnly,
        'is_custom_deck': _isCustomDeck,
      },
    );
  }

  /// Load daily ad availability status
  Future<void> _loadAdAvailability() async {
    if (_isPremiumOnlyDeck) {
      // Premium-only decks cannot be unlocked with ads
      setState(() {
        _canWatchAd = false;
        _remainingAdsToday = 0;
      });
      return;
    }

    try {
      final canWatch = await _adService.canWatchRewardedAd();
      final remaining = await _adService.getRemainingAdsToday();

      if (mounted) {
        setState(() {
          _canWatchAd = canWatch;
          _remainingAdsToday = remaining;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load ad availability: $e');
    }
  }

  /// Load RevenueCat offerings
  Future<void> _loadOfferings() async {
    setState(() => _isLoadingOfferings = true);

    try {
      final offerings = await _purchasesService.refreshOfferings();

      if (offerings?.current != null) {
        final packages = offerings!.current!.availablePackages;
        debugPrint('📦 Loaded ${packages.length} packages');

        // Check if yearly product has a free trial (introductory offer)
        bool hasFreeTrial = false;
        String trialDuration = '';
        String trialBadge = '';

        final yearlyPackage = offerings.current?.annual;
        if (yearlyPackage != null) {
          final intro = yearlyPackage.storeProduct.introductoryPrice;
          debugPrint('📦 Yearly intro price: $intro');
          if (intro != null && intro.price == 0) {
            hasFreeTrial = true;
            final units = intro.periodNumberOfUnits;
            final period = intro.periodUnit;
            String periodName;
            switch (period) {
              case PeriodUnit.day:
                periodName = units == 1 ? 'DAY' : 'DAYS';
                trialDuration = '$units-$periodName';
                break;
              case PeriodUnit.week:
                periodName = units == 1 ? 'WEEK' : 'WEEKS';
                trialDuration = '$units-$periodName';
                break;
              case PeriodUnit.month:
                periodName = units == 1 ? 'MONTH' : 'MONTHS';
                trialDuration = '$units-$periodName';
                break;
              case PeriodUnit.year:
                periodName = units == 1 ? 'YEAR' : 'YEARS';
                trialDuration = '$units-$periodName';
                break;
              default:
                trialDuration = '$units-DAY';
            }
            trialBadge = '$trialDuration FREE TRIAL';
            debugPrint('✅ Yearly has free trial: $trialBadge');
          } else {
            debugPrint('⚠️ Yearly product has NO free trial configured');
          }
        }

        setState(() {
          _availablePackages = packages;
          _yearlyHasFreeTrial = hasFreeTrial;
          _trialDurationText = trialDuration;
          _trialBadgeText = trialBadge;

          if (offerings.current?.annual != null) {
            _selectedPackage = offerings.current?.annual;
            _selectedPlanType = 'yearly';
          } else if (offerings.current?.lifetime != null) {
            _selectedPackage = offerings.current?.lifetime;
            _selectedPlanType = 'lifetime';
          } else if (offerings.current?.monthly != null) {
            _selectedPackage = offerings.current?.monthly;
            _selectedPlanType = 'monthly';
          } else if (packages.isNotEmpty) {
            _selectedPackage = packages.first;
          }
        });

        // Auto-scroll to reveal the weekend pass after content renders
        _autoScrollToRevealWeekendPass();
      }
    } catch (e) {
      debugPrint('❌ Failed to load offerings: $e');
    } finally {
      setState(() => _isLoadingOfferings = false);
    }
  }

  /// Smoothly auto-scroll so the weekend pass card is visible to the user.
  /// Waits for animations to settle, then scrolls down to the bottom
  /// to reveal the weekend pass, and scrolls back to the top.
  void _autoScrollToRevealWeekendPass() {
    // Wait for the pricing section to render and entrance animations to finish
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      // Scroll all the way to the bottom to fully reveal the weekend pass
      _scrollController
          .animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic,
          )
          .then((_) {
            // After a brief pause, scroll back to top
            if (!mounted || !_scrollController.hasClients) return;
            Future.delayed(const Duration(milliseconds: 800), () {
              if (!mounted || !_scrollController.hasClients) return;
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOutCubic,
              );
            });
          });
    });
  }

  void _initializeSparkles() {
    final screenSize = MediaQuery.of(context).size;
    final random = Random();
    final totalHeight = screenSize.height + 100;

    // Create sparkles evenly distributed across the screen
    for (int i = 0; i < 25; i++) {
      // Distribute initial Y positions evenly to avoid clumping
      final initialY = (i / 25) * totalHeight;

      _sparkles.add(
        _Sparkle(
          x: random.nextDouble() * screenSize.width,
          y: initialY,
          size: 1.5 + random.nextDouble() * 2.5,
          opacity: 0.0, // Start invisible, will fade in
          speed: 0.3 + random.nextDouble() * 0.5,
          twinklePhase: random.nextDouble() * 2 * pi,
          targetOpacity: 0.3 + random.nextDouble() * 0.4,
          horizontalDrift: (random.nextDouble() - 0.5) * 0.3,
        ),
      );
    }

    _sparkleTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) {
        setState(() {
          for (var sparkle in _sparkles) {
            // Smooth vertical movement
            sparkle.y -= sparkle.speed;

            // Gentle horizontal drift with sine wave
            sparkle.x +=
                sparkle.horizontalDrift + sin(sparkle.twinklePhase * 0.5) * 0.2;
            sparkle.twinklePhase += 0.08;

            // Twinkle effect
            final twinkle = 0.7 + sin(sparkle.twinklePhase).abs() * 0.3;
            sparkle.opacity = sparkle.targetOpacity * twinkle;

            // Smooth wrap-around with fade
            if (sparkle.y < -20) {
              sparkle.y = screenSize.height + 20;
              sparkle.x = random.nextDouble() * screenSize.width;
              sparkle.horizontalDrift = (random.nextDouble() - 0.5) * 0.3;
            }

            // Keep x within bounds with smooth wrapping
            if (sparkle.x < -10) sparkle.x = screenSize.width + 10;
            if (sparkle.x > screenSize.width + 10) sparkle.x = -10;
          }
        });
      }
    });
  }

  void _initializeFloatingDecks() {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    final allDecks = deckProvider.allDecks;
    final screenSize = MediaQuery.of(context).size;
    final random = Random();

    final deckCount = min(10, allDecks.length);
    final totalHeight = screenSize.height + 200;

    for (int i = 0; i < deckCount; i++) {
      // Distribute decks evenly across the full height for seamless flow
      final initialY = (i / deckCount) * totalHeight - 50;
      // Stagger X positions to avoid vertical alignment
      final initialX =
          ((i % 3) / 3 + random.nextDouble() * 0.3) * screenSize.width;

      _floatingDecks.add(
        _FloatingDeck(
          deck: allDecks[i % allDecks.length],
          x: initialX,
          y: initialY,
          scale:
              0.5 + random.nextDouble() * 0.35, // Larger scale for visibility
          speed:
              0.3 +
              (i % 3) * 0.15 +
              random.nextDouble() * 0.25, // Varied speeds
          opacity:
              0.25 + random.nextDouble() * 0.2, // Higher opacity for visibility
          angle: random.nextDouble() * 2 * pi,
          horizontalSpeed: (random.nextDouble() - 0.5) * 0.2,
          rotationSpeed: 0.008 + random.nextDouble() * 0.012,
        ),
      );
    }

    _deckAnimationTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) {
        setState(() {
          for (int i = 0; i < _floatingDecks.length; i++) {
            final deck = _floatingDecks[i];

            // Smooth upward movement
            deck.y -= deck.speed;

            // Gentle horizontal sway using sine wave
            deck.x += deck.horizontalSpeed + sin(deck.angle) * 0.2;
            deck.angle += deck.rotationSpeed;

            // Seamless vertical wrap - reset when fully off screen
            if (deck.y < -150) {
              deck.y = screenSize.height + 100 + random.nextDouble() * 50;
              // Randomize X position but keep some spread
              deck.x = random.nextDouble() * screenSize.width;
              deck.horizontalSpeed = (random.nextDouble() - 0.5) * 0.15;
            }

            // Smooth horizontal wrapping
            if (deck.x < -100) deck.x = screenSize.width + 50;
            if (deck.x > screenSize.width + 100) deck.x = -50;
          }
        });
      }
    });

    setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _scrollController.dispose();
    _deckAnimationTimer?.cancel();
    _sparkleTimer?.cancel();
    super.dispose();
  }

  /// Show the rewarded ad
  Future<void> _showRewardedAd() async {
    _hapticService.mediumImpact();

    // Check if this deck is premium-only or a custom deck (no ads allowed)
    if (_isPremiumOnlyDeck) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isCustomDeck
                ? 'Custom decks require Premium. Ads not available.'
                : 'This deck requires Premium. Ads not available.',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13.sp),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16.s),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.s),
          ),
        ),
      );
      return;
    }

    // Check if user has reached daily ad limit
    if (!_canWatchAd || _remainingAdsToday <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No more free plays today. Go Premium for unlimited access!',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13.sp),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16.s),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.s),
          ),
        ),
      );
      return;
    }

    // Check if ad is ready; if not, load and wait for it (up to 15 seconds)
    if (!_adService.isRewardedAdReady) {
      setState(() {
        _isLoadingAd = true;
      });

      final completer = Completer<void>();
      _adService.loadRewardedAd(
        onLoaded: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for ad to load (callback) or timeout after 15 seconds
      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      if (!mounted) return;
      if (!_adService.isRewardedAdReady) {
        if (mounted) {
          setState(() {
            _isLoadingAd = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ad not available right now. Please try again.',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13.sp),
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16.s),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.s),
              ),
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isLoadingAd = true;
    });

    // Show the rewarded ad
    await _adService.showRewardedAd(
      rewardType: 'play_deck',
      onUserEarnedReward: (amount) async {
        // User watched the ad and earned the reward
        debugPrint('🎉 User earned reward: $amount');

        // Increment daily ad count
        await _adService.incrementDailyAdCount();

        if (mounted) {
          setState(() {
            _isLoadingAd = false;
            _remainingAdsToday = (_remainingAdsToday - 1).clamp(
              0,
              AdService.maxDailyRewardedAds,
            );
            _canWatchAd = _remainingAdsToday > 0;
          });

          // Give haptic feedback for success
          _hapticService.mediumImpact();

          // Call the callback to start the game
          widget.onWatchAd();
        }
      },
    );

    // Reset loading state if ad was dismissed without earning reward
    if (mounted) {
      setState(() {
        _isLoadingAd = false;
      });
    }
  }

  /// Purchase the selected package
  Future<void> _purchaseSelectedPackage() async {
    if (_selectedPackage == null) {
      _showErrorSnackBar(
        _selectedPlanType == 'weekend'
            ? 'Weekend Pass is not available yet. Please choose another plan.'
            : 'No package selected. Please choose a plan.',
      );
      return;
    }

    _hapticService.mediumImpact();
    setState(() => _isLoadingPurchase = true);

    // Log purchase started event
    FirebaseService().logEvent(
      'purchase_started',
      parameters: {
        'product_id': _selectedPackage!.storeProduct.identifier,
        'package_type': _selectedPackage!.packageType.name,
        'price': _selectedPackage!.storeProduct.price,
        'currency': _selectedPackage!.storeProduct.currencyCode,
      },
    );

    try {
      final result = await _purchasesService.purchasePackage(_selectedPackage!);

      if (!mounted) return;

      switch (result) {
        case PurchaseResult.success:
          _hapticService.mediumImpact();

          // If this is a Weekend Pass purchase, start the 48-hour timer
          final productId =
              _selectedPackage!.storeProduct.identifier.toLowerCase();
          if (productId.contains('weekend')) {
            await _purchasesService.activateWeekendPass();
          }

          _showSuccessSnackBar(result.message);
          // Close paywall and proceed
          widget.onPurchasePremium();
          break;

        case PurchaseResult.cancelled:
          // User cancelled, no need to show message
          // Log purchase cancelled event
          FirebaseService().logEvent(
            'purchase_cancelled',
            parameters: {
              'product_id': _selectedPackage!.storeProduct.identifier,
              'package_type': _selectedPackage!.packageType.name,
            },
          );
          break;

        case PurchaseResult.alreadyOwned:
          _showSuccessSnackBar('You already have premium access!');
          widget.onPurchasePremium();
          break;

        case PurchaseResult.pending:
          _showInfoSnackBar(result.message);
          break;

        default:
          // Log purchase failed event
          FirebaseService().logEvent(
            'purchase_failed',
            parameters: {
              'product_id': _selectedPackage!.storeProduct.identifier,
              'package_type': _selectedPackage!.packageType.name,
              'error_type': result.name,
            },
          );
          _showErrorSnackBar(result.message);
      }
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      // Log purchase failed event
      FirebaseService().logEvent(
        'purchase_failed',
        parameters: {
          'product_id': _selectedPackage!.storeProduct.identifier,
          'package_type': _selectedPackage!.packageType.name,
          'error_type': 'exception',
          'error_message': e.toString().substring(
            0,
            min(100, e.toString().length),
          ),
        },
      );
      _showErrorSnackBar('Purchase failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPurchase = false);
      }
    }
  }

  /// Restore purchases
  Future<void> _restorePurchases() async {
    _hapticService.lightImpact();
    setState(() => _isLoadingPurchase = true);

    // Log restore started event
    FirebaseService().logEvent('restore_started');

    try {
      final result = await _purchasesService.restorePurchases();

      if (!mounted) return;

      switch (result) {
        case RestoreResult.success:
          _hapticService.mediumImpact();
          _showSuccessSnackBar(result.message);
          // Log restore completed event (success already logged in PurchasesService)
          widget.onPurchasePremium();
          break;

        case RestoreResult.noPurchases:
          _showInfoSnackBar(result.message);
          FirebaseService().logEvent(
            'restore_completed',
            parameters: {'result': 'no_purchases'},
          );
          break;

        default:
          FirebaseService().logEvent(
            'restore_completed',
            parameters: {'result': 'error', 'error_type': result.name},
          );
          _showErrorSnackBar(result.message);
      }
    } catch (e) {
      debugPrint('❌ Restore error: $e');
      FirebaseService().logEvent(
        'restore_completed',
        parameters: {'result': 'exception'},
      );
      _showErrorSnackBar('Failed to restore purchases.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPurchase = false);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20.s),
            SizedBox(width: 8.s),
            Expanded(
              child: Text(message, style: GoogleFonts.inter(fontSize: 13.sp)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.s),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.s),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20.s),
            SizedBox(width: 8.s),
            Expanded(
              child: Text(message, style: GoogleFonts.inter(fontSize: 13.sp)),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.s),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.s),
        ),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20.s),
            SizedBox(width: 8.s),
            Expanded(
              child: Text(message, style: GoogleFonts.inter(fontSize: 13.sp)),
            ),
          ],
        ),
        backgroundColor: Colors.blueGrey.shade700,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.s),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.s),
        ),
      ),
    );
  }

  /// Launch a URL in the default browser
  Future<void> _launchUrl(String url) async {
    _hapticService.lightImpact();

    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not open link');
      }
    } catch (e) {
      debugPrint('❌ Failed to launch URL: $e');
      _showErrorSnackBar('Could not open link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Premium dark background - Netflix style
          Container(color: const Color(0xFF0A0A0A)),

          // Subtle top glow from selected deck color
          Positioned(
            top: -100.h,
            left: -50.w,
            right: -50.w,
            child: Container(
              height: screenSize.height * 0.5,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    widget.selectedDeck.color.withOpacity(0.15),
                    widget.selectedDeck.color.withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Subtle ambient glow at bottom (golden premium accent)
          Positioned(
            bottom: -50.h,
            left: 0,
            right: 0,
            child: Container(
              height: 300.h,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 1.5,
                  colors: [
                    const Color(0xFFFFD700).withOpacity(0.08),
                    const Color(0xFFFFD700).withOpacity(0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          // Floating deck images background
          ..._floatingDecks.map(
            (floatingDeck) => Positioned(
              left: floatingDeck.x - 50.s,
              top: floatingDeck.y,
              child: Transform.scale(
                scale: floatingDeck.scale,
                child: Transform.rotate(
                  angle: sin(floatingDeck.angle) * 0.1,
                  // Use ColorFiltered instead of Opacity to avoid Impeller issues
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withAlpha(
                        (255 * (1 - floatingDeck.opacity)).toInt(),
                      ),
                      BlendMode.dstOut,
                    ),
                    child: Container(
                      width: 100.s,
                      height: 140.s,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.s),
                        boxShadow: [
                          BoxShadow(
                            color: floatingDeck.deck.color.withAlpha(
                              (255 * 0.4 * floatingDeck.opacity).toInt(),
                            ),
                            blurRadius: 20.s,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.s),
                        child:
                            floatingDeck.deck.imageUrl != null &&
                                    floatingDeck.deck.imageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                  imageUrl: floatingDeck.deck.imageUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 100,
                                  memCacheHeight: 140,
                                  placeholder:
                                      (_, __) => Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              floatingDeck.deck.color,
                                              floatingDeck.deck.color.withAlpha(
                                                179,
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          floatingDeck.deck.icon,
                                          color: Colors.white.withAlpha(153),
                                          size: 36.s,
                                        ),
                                      ),
                                  errorWidget:
                                      (_, __, ___) => Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              floatingDeck.deck.color,
                                              floatingDeck.deck.color.withAlpha(
                                                179,
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          floatingDeck.deck.icon,
                                          color: Colors.white.withAlpha(153),
                                          size: 36.s,
                                        ),
                                      ),
                                )
                                : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        floatingDeck.deck.color,
                                        floatingDeck.deck.color.withAlpha(179),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    floatingDeck.deck.icon,
                                    color: Colors.white.withAlpha(153),
                                    size: 36.s,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Subtle blur overlay - less opaque to show deck images
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

          // Sparkle particles - use color opacity instead of Opacity widget to avoid Impeller issues
          ..._sparkles.map(
            (sparkle) => Positioned(
              left: sparkle.x,
              top: sparkle.y,
              child: Container(
                width: sparkle.size,
                height: sparkle.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(
                    (255 * sparkle.opacity).toInt(),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFFFD700,
                      ).withAlpha((255 * 0.4 * sparkle.opacity).toInt()),
                      blurRadius: sparkle.size * 2,
                      spreadRadius: sparkle.size / 3,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 20.s),
                    child: Column(
                      children: [
                        SizedBox(height: 8.h),

                        // Header section with icon, title, and close button
                        _buildCompactHeader(),

                        SizedBox(height: 24.h),

                        // Feature chips
                        _buildFeatureChips(),

                        SizedBox(height: 20.h),

                        // Pricing packages
                        _buildPricingSection(),

                        SizedBox(height: 16.h),

                        // Limited time offer badge
                        _buildLimitedOfferBadge(),

                        // Extra space to allow scrolling content above the fixed bottom section
                        SizedBox(height: 260.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Fixed bottom action section
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomActionSection(bottomPadding),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Column(
      children: [
        // Premium header row with close button - Netflix style
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Premium badge - elegant and compact
            Container(
                  width: 48.s,
                  height: 48.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFFA500),
                        Color(0xFFFF8C00),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.4),
                        blurRadius: 12.s,
                        offset: Offset(0, 3.s),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 24.s,
                  ),
                )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                ),

            SizedBox(width: 12.s),

            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                        'Go Premium',
                        style: GoogleFonts.poppins(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideX(
                        begin: 0.1,
                        end: 0,
                        delay: 100.ms,
                        duration: 400.ms,
                      ),

                  SizedBox(height: 2.h),

                  Text(
                    'Unlock the ultimate party experience',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: -0.1,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                ],
              ),
            ),

            // Close button - inline with header
            Semantics(
                  label: 'Close paywall',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      _hapticService.lightImpact();
                      widget.onClose();
                    },
                    child: Container(
                      width: 36.s,
                      height: 36.s,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 20.s,
                      ),
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: 300.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 300.ms,
                ),
          ],
        ),

        SizedBox(height: 18.h),

        // Selected deck card - cinematic Netflix style
        Container(
              padding: EdgeInsets.all(10.s),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(14.s),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Deck thumbnail
                  Container(
                    width: 48.s,
                    height: 64.s,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.s),
                      boxShadow: [
                        BoxShadow(
                          color: widget.selectedDeck.color.withOpacity(0.4),
                          blurRadius: 12.s,
                          offset: Offset(0, 4.s),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.s),
                      child:
                          widget.selectedDeck.imageUrl != null
                              ? CachedNetworkImage(
                                imageUrl: widget.selectedDeck.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget:
                                    (_, __, ___) => _buildDeckPlaceholder(),
                              )
                              : _buildDeckPlaceholder(),
                    ),
                  ),

                  SizedBox(width: 12.s),

                  // Deck info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label with play icon
                        Row(
                          children: [
                            Icon(
                              Icons.videogame_asset_rounded,
                              color: const Color(0xFF4CAF50),
                              size: 12.s,
                            ),
                            SizedBox(width: 4.s),
                            Text(
                              'Ready to play',
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4CAF50),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3.h),
                        // Deck name
                        Text(
                          widget.selectedDeck.name,
                          style: GoogleFonts.poppins(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1.h),
                        // Card count
                        Text(
                          '${widget.selectedDeck.cards.length} cards',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(delay: 300.ms, duration: 400.ms)
            .slideY(begin: 0.08, end: 0, delay: 300.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildDeckPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.selectedDeck.color,
            widget.selectedDeck.color.withOpacity(0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          widget.selectedDeck.icon,
          color: Colors.white.withOpacity(0.8),
          size: 22.s,
        ),
      ),
    );
  }

  Widget _buildFeatureChips() {
    return Wrap(
      spacing: 8.s,
      runSpacing: 8.s,
      children: List.generate(_premiumFeatures.length, (index) {
        final feature = _premiumFeatures[index];

        return Container(
              width: (MediaQuery.of(context).size.width - 40.s - 8.s) / 2 - 4.s,
              padding: EdgeInsets.symmetric(vertical: 10.s, horizontal: 8.s),
              decoration: BoxDecoration(
                color: feature.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12.s),
                border: Border.all(
                  color: feature.color.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 32.s,
                    height: 32.s,
                    decoration: BoxDecoration(
                      color: feature.color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(feature.icon, color: feature.color, size: 16.s),
                  ),
                  SizedBox(width: 8.s),
                  // Title
                  Flexible(
                    child: Text(
                      feature.title,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.85),
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(delay: (400 + index * 50).ms, duration: 350.ms)
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              delay: (400 + index * 50).ms,
              duration: 350.ms,
              curve: Curves.easeOut,
            );
      }),
    );
  }

  Widget _buildPricingSection() {
    if (_isLoadingOfferings) {
      return Container(
        padding: EdgeInsets.all(20.s),
        child: Center(
          child: SizedBox(
            width: 24.s,
            height: 24.s,
            child: CircularProgressIndicator(
              color: const Color(0xFFFFD700),
              strokeWidth: 2.s,
            ),
          ),
        ),
      );
    }

    // Build elegant pricing cards
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // YEARLY - Premium highlighted card with FREE TRIAL
        _buildYearlyCard(
          delay: 500,
          onTap: () => _selectPlan('yearly'),
          isSelected: _getSelectedPlanType() == 'yearly',
        ),

        SizedBox(height: 12.h),

        // Row for Monthly and Lifetime - Glass cards
        Builder(builder: (context) {
          final monthlyPkg = _availablePackages.where(
            (p) => p.packageType == PackageType.monthly || p.identifier.toLowerCase().contains('month'),
          ).firstOrNull;
          final lifetimePkg = _availablePackages.where(
            (p) => p.packageType == PackageType.lifetime || p.identifier.toLowerCase().contains('lifetime'),
          ).firstOrNull;

          return Row(
            children: [
              Expanded(
                child: _buildGlassCard(
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFF64B5F6),
                  title: 'Monthly',
                  price: monthlyPkg?.storeProduct.priceString ?? '\$2.99',
                  period: '/month',
                  description: 'Flexible billing',
                  delay: 600,
                  onTap: () => _selectPlan('monthly'),
                  isSelected: _getSelectedPlanType() == 'monthly',
                ),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: _buildGlassCard(
                  icon: Icons.all_inclusive_rounded,
                  iconColor: const Color(0xFFFFD700),
                  title: 'Lifetime',
                  price: lifetimePkg?.storeProduct.priceString ?? '\$29.99',
                  period: '',
                  description: 'One-time forever',
                  badge: 'BEST',
                  delay: 650,
                  onTap: () => _selectPlan('lifetime'),
                  isSelected: _getSelectedPlanType() == 'lifetime',
                ),
              ),
            ],
          );
        }),

        SizedBox(height: 12.h),

        // WEEKEND PASS - Party card
        _buildWeekendPassCard(
          delay: 700,
          onTap: () => _selectPlan('weekend'),
          isSelected: _getSelectedPlanType() == 'weekend',
        ),
      ],
    );
  }

  String _getSelectedPlanType() {
    return _selectedPlanType;
  }

  void _selectPlan(String planType) {
    _hapticService.lightImpact();
    Package? selectedPackage;

    for (var package in _availablePackages) {
      final id = package.identifier.toLowerCase();
      if (planType == 'weekend' &&
          (id.contains('weekend') || id.contains('48h'))) {
        selectedPackage = package;
        break;
      } else if (planType == 'lifetime' &&
          (package.packageType == PackageType.lifetime ||
              id.contains('lifetime'))) {
        selectedPackage = package;
        break;
      } else if (planType == 'yearly' &&
          (package.packageType == PackageType.annual ||
              id.contains('year') ||
              id.contains('annual'))) {
        selectedPackage = package;
        break;
      } else if (planType == 'monthly' &&
          (package.packageType == PackageType.monthly ||
              id.contains('month'))) {
        selectedPackage = package;
        break;
      }
    }

    setState(() {
      _selectedPlanType = planType;
      // Only update _selectedPackage if we found the matching package.
      // If the package was not found (e.g. Weekend Pass not yet configured
      // in RevenueCat), keep _selectedPackage as null so the purchase button
      // shows an error instead of silently purchasing the wrong plan.
      _selectedPackage = selectedPackage;
    });
  }

  /// Premium Yearly Card - The hero card with optional free trial
  Widget _buildYearlyCard({
    required int delay,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    final yearlyPackage = _availablePackages.where(
      (p) => p.packageType == PackageType.annual || p.identifier.toLowerCase().contains('year'),
    ).firstOrNull;
    final priceString = yearlyPackage?.storeProduct.priceString ?? '\$14.99';

    return Semantics(
      label:
          'Yearly plan, $priceString per year${_yearlyHasFreeTrial ? ' with $_trialBadgeText' : ''}${isSelected ? ', selected' : ''}',
      button: true,
      child: GestureDetector(
        onTap: () {
          debugPrint('Yearly card tapped');
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.s),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1A2E).withOpacity(0.95),
                const Color(0xFF16213E).withOpacity(0.9),
              ],
            ),
            border: Border.all(
              color:
                  isSelected
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF4CAF50).withOpacity(0.4),
              width: isSelected ? 2.5.s : 1.5.s,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF4CAF50,
                ).withOpacity(isSelected ? 0.3 : 0.15),
                blurRadius: 24.s,
                offset: Offset(0, 8.s),
                spreadRadius: -4.s,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16.s,
                offset: Offset(0, 4.s),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle glow overlay
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.s),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topRight,
                        radius: 1.5,
                        colors: [
                          const Color(0xFF4CAF50).withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(18.s),
                child: Column(
                  children: [
                    // Top row - Badge centered (only show if free trial is available)
                    if (_yearlyHasFreeTrial)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.s,
                          vertical: 6.s,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                          ),
                          borderRadius: BorderRadius.circular(20.s),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.4),
                              blurRadius: 12.s,
                              offset: Offset(0, 4.s),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 14.s,
                            ),
                            SizedBox(width: 6.s),
                            Text(
                              _trialBadgeText,
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_yearlyHasFreeTrial) SizedBox(height: 16.h),

                    // Main content row
                    Row(
                      children: [
                        // Selection circle
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 26.s,
                          height: 26.s,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient:
                                isSelected
                                    ? const LinearGradient(
                                      colors: [
                                        Color(0xFF4CAF50),
                                        Color(0xFF2E7D32),
                                      ],
                                    )
                                    : null,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.transparent
                                      : Colors.white.withOpacity(0.3),
                              width: 2.s,
                            ),
                          ),
                          child:
                              isSelected
                                  ? Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16.s,
                                  )
                                  : null,
                        ),

                        SizedBox(width: 14.s),

                        // Plan info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Yearly',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8.s),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.s,
                                      vertical: 3.s,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4CAF50,
                                      ).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6.s),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF4CAF50,
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'POPULAR',
                                      style: GoogleFonts.inter(
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF4CAF50),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _yearlyHasFreeTrial
                                    ? 'Try free for ${_trialDurationText.replaceAll('-', ' ').toLowerCase()}, then $priceString/year'
                                    : '$priceString/year',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Price column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  priceString,
                                  style: GoogleFonts.poppins(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 4.s, left: 2.s),
                                  child: Text(
                                    '/yr',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.s,
                                vertical: 3.s,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF4CAF50).withOpacity(0.2),
                                    const Color(0xFF4CAF50).withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6.s),
                              ),
                              child: Text(
                                'Save 58%',
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Elegant glass card for Monthly/Lifetime
  Widget _buildGlassCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String price,
    required String period,
    required String description,
    required int delay,
    required VoidCallback onTap,
    required bool isSelected,
    String? badge,
  }) {
    return Semantics(
      label:
          '$title plan, $price$period, $description${isSelected ? ', selected' : ''}',
      button: true,
      child: GestureDetector(
        onTap: () {
          debugPrint('Glass card tapped: $title');
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(14.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.s),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isSelected
                      ? [
                        iconColor.withOpacity(0.15),
                        iconColor.withOpacity(0.05),
                      ]
                      : [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.03),
                      ],
            ),
            border: Border.all(
              color:
                  isSelected
                      ? iconColor.withOpacity(0.8)
                      : Colors.white.withOpacity(0.12),
              width: isSelected ? 2.s : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: iconColor.withOpacity(0.2),
                        blurRadius: 16.s,
                        offset: Offset(0, 4.s),
                      ),
                    ]
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row - Icon and badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon
                  Container(
                    width: 36.s,
                    height: 36.s,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          iconColor.withOpacity(0.25),
                          iconColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10.s),
                      border: Border.all(color: iconColor.withOpacity(0.2)),
                    ),
                    child: Icon(icon, color: iconColor, size: 18.s),
                  ),

                  // Badge or selection indicator
                  if (badge != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.s,
                        vertical: 3.s,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [iconColor, iconColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(6.s),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.inter(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    )
                  else
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 20.s,
                      height: 20.s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            isSelected
                                ? LinearGradient(
                                  colors: [
                                    iconColor,
                                    iconColor.withOpacity(0.8),
                                  ],
                                )
                                : null,
                        border: Border.all(
                          color:
                              isSelected
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.25),
                          width: 2.s,
                        ),
                      ),
                      child:
                          isSelected
                              ? Icon(
                                Icons.check,
                                color: Colors.black,
                                size: 12.s,
                              )
                              : null,
                    ),
                ],
              ),

              SizedBox(height: 12.h),

              // Title
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: 4.h),

              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: GoogleFonts.poppins(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? iconColor : Colors.white,
                      height: 1,
                    ),
                  ),
                  if (period.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 2.s, left: 2.s),
                      child: Text(
                        period,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 6.h),

              // Description
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Weekend Pass - Party themed card
  Widget _buildWeekendPassCard({
    required int delay,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return Semantics(
      label:
          'Weekend pass, 48 hours of unlimited access${isSelected ? ', selected' : ''}',
      button: true,
      child: GestureDetector(
        onTap: () {
          debugPrint('Weekend Pass card tapped');
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(14.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.s),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isSelected
                      ? [
                        const Color(0xFFE91E63).withOpacity(0.2),
                        const Color(0xFF9C27B0).withOpacity(0.15),
                      ]
                      : [
                        const Color(0xFFE91E63).withOpacity(0.08),
                        const Color(0xFF9C27B0).withOpacity(0.05),
                      ],
            ),
            border: Border.all(
              color:
                  isSelected
                      ? const Color(0xFFE91E63).withOpacity(0.8)
                      : const Color(0xFFE91E63).withOpacity(0.25),
              width: isSelected ? 2.s : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withOpacity(0.2),
                        blurRadius: 16.s,
                        offset: Offset(0, 4.s),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            children: [
              // Party icon
              Container(
                width: 44.s,
                height: 44.s,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.circular(12.s),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE91E63).withOpacity(0.3),
                      blurRadius: 8.s,
                      offset: Offset(0, 2.s),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.celebration_rounded,
                  color: Colors.white,
                  size: 22.s,
                ),
              ),

              SizedBox(width: 14.s),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Weekend Pass',
                            style: GoogleFonts.poppins(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.s),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.s,
                            vertical: 2.s,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                            ),
                            borderRadius: BorderRadius.circular(4.s),
                          ),
                          child: Text(
                            '48H',
                            style: GoogleFonts.inter(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Perfect for party night!',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),

              // Price and selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$0.99',
                    style: GoogleFonts.poppins(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected ? const Color(0xFFE91E63) : Colors.white,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 22.s,
                    height: 22.s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          isSelected
                              ? const LinearGradient(
                                colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                              )
                              : null,
                      border: Border.all(
                        color:
                            isSelected
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.25),
                        width: 2.s,
                      ),
                    ),
                    child:
                        isSelected
                            ? Icon(Icons.check, color: Colors.white, size: 14.s)
                            : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLimitedOfferBadge() {
    if (!_yearlyHasFreeTrial) return const SizedBox.shrink();

    final trialLabel = _trialDurationText.replaceAll('-', ' ');

    return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 8.s),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4CAF50).withOpacity(0.15),
                const Color(0xFF2E7D32).withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(24.s),
            border: Border.all(
              color: const Color(0xFF4CAF50).withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(3.s),
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 12.s,
                ),
              ),
              SizedBox(width: 8.s),
              Text(
                'START FREE TRIAL',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4CAF50),
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(width: 6.s),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.s, vertical: 2.s),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.s),
                ),
                child: Text(
                  '$trialLabel FREE',
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 600.ms, duration: 400.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          delay: 600.ms,
          duration: 400.ms,
          curve: Curves.easeOutBack,
        )
        .shimmer(
          delay: 1200.ms,
          duration: 1800.ms,
          color: const Color(0xFF4CAF50).withOpacity(0.25),
        );
  }

  Widget _buildBottomActionSection(double bottomPadding) {
    final selectedPlan = _getSelectedPlanType();
    final isYearlySelected = selectedPlan == 'yearly';
    final isWeekendSelected = selectedPlan == 'weekend';

    // Dynamic button text based on selection
    String buttonText;
    String buttonSubtext;
    Color primaryColor;
    Color secondaryColor;

    // Get actual price for yearly plan
    final yearlyPkg = _availablePackages.where(
      (p) => p.packageType == PackageType.annual || p.identifier.toLowerCase().contains('year'),
    ).firstOrNull;
    final yearlyPrice = yearlyPkg?.storeProduct.priceString ?? '\$14.99';

    if (isYearlySelected) {
      if (_yearlyHasFreeTrial) {
        buttonText = 'Start ${_trialDurationText.replaceAll('-', ' ')} Free Trial';
        buttonSubtext = 'Then $yearlyPrice/year • Cancel anytime';
      } else {
        buttonText = 'Subscribe Yearly';
        buttonSubtext = '$yearlyPrice/year • Cancel anytime';
      }
      primaryColor = const Color(0xFF4CAF50);
      secondaryColor = const Color(0xFF2E7D32);
    } else if (isWeekendSelected) {
      buttonText = 'Get Weekend Pass';
      buttonSubtext = '48 hours of unlimited access';
      primaryColor = const Color(0xFFE91E63);
      secondaryColor = const Color(0xFF9C27B0);
    } else if (selectedPlan == 'lifetime') {
      final lifetimePkg = _availablePackages.where(
        (p) => p.packageType == PackageType.lifetime || p.identifier.toLowerCase().contains('lifetime'),
      ).firstOrNull;
      final lifetimePrice = lifetimePkg?.storeProduct.priceString ?? '\$29.99';
      buttonText = 'Unlock Forever';
      buttonSubtext = 'One-time payment of $lifetimePrice';
      primaryColor = const Color(0xFFFFD700);
      secondaryColor = const Color(0xFFFFA500);
    } else {
      final monthlyPkg = _availablePackages.where(
        (p) => p.packageType == PackageType.monthly || p.identifier.toLowerCase().contains('month'),
      ).firstOrNull;
      final monthlyPrice = monthlyPkg?.storeProduct.priceString ?? '\$2.99';
      buttonText = 'Subscribe Now';
      buttonSubtext = '$monthlyPrice/month • Cancel anytime';
      primaryColor = const Color(0xFFFFD700);
      secondaryColor = const Color(0xFFFFA500);
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20.s, 16.h, 20.s, bottomPadding + 16.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.95),
              ],
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PRIMARY: Subscribe/Start Trial button
              Semantics(
                    label: '$buttonText, $buttonSubtext',
                    button: true,
                    child: GestureDetector(
                      onTap:
                          _isLoadingPurchase ? null : _purchaseSelectedPackage,
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return AnimatedOpacity(
                            opacity: _isLoadingPurchase ? 0.7 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: double.infinity,
                              height: 60.h,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [primaryColor, secondaryColor],
                                ),
                                borderRadius: BorderRadius.circular(16.s),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.4),
                                    blurRadius: 20.s,
                                    offset: Offset(0, 6.s),
                                    spreadRadius: -4.s,
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Shimmer effect
                                  if (!_isLoadingPurchase)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16.s),
                                      child: Transform.translate(
                                        offset: Offset(
                                          -200 +
                                              (_shimmerController.value * 600),
                                          0,
                                        ),
                                        child: Container(
                                          width: 80.s,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Colors.white.withOpacity(0.2),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Content
                                  Center(
                                    child:
                                        _isLoadingPurchase
                                            ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 22.s,
                                                  height: 22.s,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.5.s,
                                                      ),
                                                ),
                                                SizedBox(width: 12.s),
                                                Text(
                                                  'Processing...',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  buttonText,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 17.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                SizedBox(height: 2.h),
                                                Text(
                                                  buttonSubtext,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white
                                                        .withOpacity(0.85),
                                                  ),
                                                ),
                                              ],
                                            ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 700.ms, duration: 400.ms),

              SizedBox(height: 12.h),

              // SECONDARY: Watch Ad to Continue for Free
              // Hide completely for premium-only decks
              if (!_isPremiumOnlyDeck)
                _buildAdButton()
                    .animate()
                    .fadeIn(delay: 800.ms, duration: 400.ms)
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      delay: 800.ms,
                      duration: 400.ms,
                    ),

              // Show premium-only message if deck doesn't allow ads
              if (_isPremiumOnlyDeck)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: 12.s,
                    horizontal: 16.s,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isCustomDeck
                            ? const Color(0xFF9C27B0).withOpacity(0.1)
                            : const Color(0xFFFFD700).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.s),
                    border: Border.all(
                      color:
                          _isCustomDeck
                              ? const Color(0xFF9C27B0).withOpacity(0.3)
                              : const Color(0xFFFFD700).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isCustomDeck
                            ? Icons.create_rounded
                            : Icons.star_rounded,
                        color:
                            _isCustomDeck
                                ? const Color(0xFF9C27B0)
                                : const Color(0xFFFFD700),
                        size: 18.s,
                      ),
                      SizedBox(width: 8.s),
                      Flexible(
                        child: Text(
                          _isCustomDeck
                              ? 'Custom decks require Premium to play'
                              : 'This exclusive deck requires Premium',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color:
                                _isCustomDeck
                                    ? const Color(0xFF9C27B0)
                                    : const Color(0xFFFFD700),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 800.ms, duration: 400.ms),

              SizedBox(height: 12.h),

              // Footer links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isLoadingPurchase ? null : _restorePurchases,
                    child: Text(
                      'Restore Purchases',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ),
                  Text(
                    '  •  ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12.sp,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _launchUrl(_termsOfServiceUrl),
                    child: Text(
                      'Terms',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.5),
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Text(
                    '  •  ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12.sp,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _launchUrl(_privacyPolicyUrl),
                    child: Text(
                      'Privacy',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.5),
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the "Watch Ad" button with progressive messaging
  Widget _buildAdButton() {
    // Determine if button should be disabled
    final bool isDisabled = !_canWatchAd || _remainingAdsToday <= 0;

    // Get progressive message from AdService
    final String adMessage = _adService.getProgressiveAdMessage();
    final String adSubMessage = _adService.getProgressiveAdSubMessage();

    // Determine button appearance based on state
    final Color buttonColor =
        isDisabled
            ? Colors.red.withOpacity(0.1)
            : Colors.white.withOpacity(0.06);
    final Color borderColor =
        isDisabled
            ? Colors.red.withOpacity(0.3)
            : Colors.white.withOpacity(0.15);
    final Color textColor =
        isDisabled
            ? Colors.red.withOpacity(0.7)
            : Colors.white.withOpacity(0.7);

    return Semantics(
      label:
          isDisabled
              ? 'Watch ad unavailable, daily limit reached'
              : 'Watch ad to play for free, $adMessage',
      button: !isDisabled,
      child: GestureDetector(
        onTap: (_isLoadingAd || isDisabled) ? null : _showRewardedAd,
        child: AnimatedOpacity(
          opacity: (_isLoadingAd || isDisabled) ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            height: 48.h,
            decoration: BoxDecoration(
              color: buttonColor,
              borderRadius: BorderRadius.circular(14.s),
              border: Border.all(color: borderColor, width: 1),
            ),
            child:
                _isLoadingAd
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18.s,
                          height: 18.s,
                          child: CircularProgressIndicator(
                            color: Colors.white.withOpacity(0.7),
                            strokeWidth: 2.s,
                          ),
                        ),
                        SizedBox(width: 10.s),
                        Text(
                          'Loading Ad...',
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isDisabled
                              ? Icons.block_rounded
                              : Icons.play_circle_outline_rounded,
                          color: textColor,
                          size: 20.s,
                        ),
                        SizedBox(width: 8.s),
                        Flexible(
                          child: Text(
                            adMessage,
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isDisabled) ...[
                          SizedBox(width: 8.s),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.s,
                              vertical: 2.s,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6.s),
                            ),
                            child: Text(
                              adSubMessage,
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

class _FloatingDeck {
  final Deck deck;
  double x;
  double y;
  double scale;
  double speed;
  double opacity;
  double angle;
  double horizontalSpeed;
  double rotationSpeed;

  _FloatingDeck({
    required this.deck,
    required this.x,
    required this.y,
    required this.scale,
    required this.speed,
    required this.opacity,
    required this.angle,
    this.horizontalSpeed = 0.0,
    this.rotationSpeed = 0.01,
  });
}

class _PremiumFeature {
  final IconData icon;
  final String title;
  final Color color;

  _PremiumFeature({
    required this.icon,
    required this.title,
    required this.color,
  });
}

class _Sparkle {
  double x;
  double y;
  double size;
  double opacity;
  double speed;
  double twinklePhase;
  double targetOpacity;
  double horizontalDrift;

  _Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
    required this.twinklePhase,
    this.targetOpacity = 0.5,
    this.horizontalDrift = 0.0,
  });
}
