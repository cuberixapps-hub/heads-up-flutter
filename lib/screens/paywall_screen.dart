import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../services/ad_service.dart';
import '../services/firebase_service.dart';
import '../services/haptic_service.dart';
import '../services/purchases_service.dart';
import '../utils/responsive.dart';

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

  // State for purchases
  bool _isLoadingPurchase = false;
  bool _isLoadingOfferings = true;
  Package? _selectedPackage;
  List<Package> _availablePackages = [];

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // Floating deck positions
  final List<_FloatingDeck> _floatingDecks = [];
  final List<_Sparkle> _sparkles = [];
  Timer? _deckAnimationTimer;
  Timer? _sparkleTimer;

  // Compact premium features (only 3 key features)
  final List<_PremiumFeature> _premiumFeatures = [
    _PremiumFeature(
      icon: Icons.all_inclusive_rounded,
      title: 'Unlimited Decks',
      color: const Color(0xFF4CAF50),
    ),
    _PremiumFeature(
      icon: Icons.block_rounded,
      title: 'No Ads',
      color: const Color(0xFFE91E63),
    ),
    _PremiumFeature(
      icon: Icons.auto_awesome_rounded,
      title: 'Exclusive Content',
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

    // Initialize floating decks and sparkles after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFloatingDecks();
      _initializeSparkles();
      _loadOfferings();
    });
    
    // Log paywall viewed event
    FirebaseService().logEvent(
      'paywall_viewed',
      parameters: {
        'deck_id': widget.selectedDeck.id,
        'deck_name': widget.selectedDeck.name,
        'is_premium_deck': widget.selectedDeck.isPremium,
      },
    );
  }

  /// Load RevenueCat offerings
  Future<void> _loadOfferings() async {
    setState(() => _isLoadingOfferings = true);

    try {
      final offerings = await _purchasesService.refreshOfferings();

      if (offerings?.current != null) {
        final packages = offerings!.current!.availablePackages;
        debugPrint('📦 Loaded ${packages.length} packages');

        setState(() {
          _availablePackages = packages;
          // Default to lifetime if available, otherwise yearly, then monthly
          _selectedPackage =
              offerings.current?.lifetime ??
              offerings.current?.annual ??
              offerings.current?.monthly ??
              (packages.isNotEmpty ? packages.first : null);
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load offerings: $e');
    } finally {
      setState(() => _isLoadingOfferings = false);
    }
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
    _deckAnimationTimer?.cancel();
    _sparkleTimer?.cancel();
    super.dispose();
  }

  /// Show the rewarded ad
  Future<void> _showRewardedAd() async {
    _hapticService.mediumImpact();

    // Check if ad is ready
    if (!_adService.isRewardedAdReady) {
      // Show loading state while we try to load the ad
      setState(() {
        _isLoadingAd = true;
      });

      // Try loading the ad
      _adService.loadRewardedAd();

      // Wait a bit for the ad to load
      await Future.delayed(const Duration(seconds: 2));

      // Check again
      if (!_adService.isRewardedAdReady) {
        if (mounted) {
          setState(() {
            _isLoadingAd = false;
          });

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ad not available right now. Please try again.',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16.s),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
      onUserEarnedReward: (amount) {
        // User watched the ad and earned the reward
        debugPrint('🎉 User earned reward: $amount');

        if (mounted) {
          setState(() {
            _isLoadingAd = false;
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
      _showErrorSnackBar('No package selected');
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
          'error_message': e.toString().substring(0, min(100, e.toString().length)),
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
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8.s),
            Expanded(child: Text(message, style: GoogleFonts.inter())),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.s),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8.s),
            Expanded(child: Text(message, style: GoogleFonts.inter())),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.s),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 8.s),
            Expanded(child: Text(message, style: GoogleFonts.inter())),
          ],
        ),
        backgroundColor: Colors.blueGrey.shade700,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.s),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
            top: -100,
            left: -50,
            right: -50,
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
            bottom: -50,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
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
              left: floatingDeck.x - 50,
              top: floatingDeck.y,
              child: Transform.scale(
                scale: floatingDeck.scale,
                child: Transform.rotate(
                  angle: sin(floatingDeck.angle) * 0.1,
                  child: Opacity(
                    opacity: floatingDeck.opacity,
                    child: Container(
                      width: 100,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: floatingDeck.deck.color.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                                              floatingDeck.deck.color
                                                  .withOpacity(0.7),
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          floatingDeck.deck.icon,
                                          color: Colors.white.withOpacity(0.6),
                                          size: 36,
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
                                              floatingDeck.deck.color
                                                  .withOpacity(0.7),
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          floatingDeck.deck.icon,
                                          color: Colors.white.withOpacity(0.6),
                                          size: 36,
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
                                        floatingDeck.deck.color.withOpacity(
                                          0.7,
                                        ),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    floatingDeck.deck.icon,
                                    color: Colors.white.withOpacity(0.6),
                                    size: 36,
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

          // Sparkle particles
          ..._sparkles.map(
            (sparkle) => Positioned(
              left: sparkle.x,
              top: sparkle.y,
              child: Opacity(
                opacity: sparkle.opacity,
                child: Container(
                  width: sparkle.size,
                  height: sparkle.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.4),
                        blurRadius: sparkle.size * 2,
                        spreadRadius: sparkle.size / 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Close button - compact
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.s,
                    vertical: 8.s,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
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
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 20,
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
                ),

                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 20.s),
                    child: Column(
                      children: [
                        // Header section with icon and selected deck
                        _buildCompactHeader(),

                        SizedBox(height: 24.s),

                        // Feature chips
                        _buildFeatureChips(),

                        SizedBox(height: 20.s),

                        // Pricing packages
                        _buildPricingSection(),

                        SizedBox(height: 16.s),

                        // Limited time offer badge
                        _buildLimitedOfferBadge(),

                        // Extra space for bottom sheet
                        SizedBox(height: 180.s),
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
        // Premium header row - Netflix style
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Premium badge - elegant and compact
            Container(
                  width: 56.s,
                  height: 56.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF66BB6A),
                        Color(0xFF4CAF50),
                        Color(0xFF2E7D32),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30.s,
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

            SizedBox(width: 14.s),

            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                        'Play Now!',
                        style: GoogleFonts.poppins(
                          fontSize: 24.sp,
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

                  SizedBox(height: 2.s),

                  Text(
                    'Watch a quick video to start playing',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: -0.1,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 18.s),

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
                borderRadius: BorderRadius.circular(14),
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
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: widget.selectedDeck.color.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
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
                              size: 12,
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
                        SizedBox(height: 3.s),
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
                        SizedBox(height: 1.s),
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
          size: 22,
        ),
      ),
    );
  }

  Widget _buildFeatureChips() {
    return Row(
      children: List.generate(_premiumFeatures.length, (index) {
        final feature = _premiumFeatures[index];
        final isLast = index == _premiumFeatures.length - 1;

        return Expanded(
          child: Container(
                margin: EdgeInsets.only(right: isLast ? 0 : 8.s),
                padding: EdgeInsets.symmetric(vertical: 12.s),
                decoration: BoxDecoration(
                  color: feature.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: feature.color.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 36.s,
                      height: 36.s,
                      decoration: BoxDecoration(
                        color: feature.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(feature.icon, color: feature.color, size: 18),
                    ),
                    SizedBox(height: 6.s),
                    // Title
                    Text(
                      feature.title,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.85),
                        letterSpacing: -0.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(delay: (400 + index * 60).ms, duration: 350.ms)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1, 1),
                delay: (400 + index * 60).ms,
                duration: 350.ms,
                curve: Curves.easeOut,
              ),
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
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_availablePackages.isEmpty) {
      // Fallback UI when no packages available
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Plan',
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.8),
          ),
        ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

        SizedBox(height: 12.s),

        // Package options
        ..._availablePackages.asMap().entries.map((entry) {
          final index = entry.key;
          final package = entry.value;
          final isSelected = _selectedPackage?.identifier == package.identifier;
          final isLifetime =
              package.packageType == PackageType.lifetime ||
              package.identifier.toLowerCase().contains('lifetime');
          final isAnnual = package.packageType == PackageType.annual;

          return GestureDetector(
                onTap: () {
                  _hapticService.lightImpact();
                  setState(() => _selectedPackage = package);
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 10.s),
                  padding: EdgeInsets.all(14.s),
                  decoration: BoxDecoration(
                    gradient:
                        isSelected
                            ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFFFD700).withOpacity(0.15),
                                const Color(0xFFFFD700).withOpacity(0.05),
                              ],
                            )
                            : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isSelected
                              ? const Color(0xFFFFD700).withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Selection indicator
                      Container(
                        width: 22.s,
                        height: 22.s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected
                                    ? const Color(0xFFFFD700)
                                    : Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                          color:
                              isSelected
                                  ? const Color(0xFFFFD700)
                                  : Colors.transparent,
                        ),
                        child:
                            isSelected
                                ? const Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 14,
                                )
                                : null,
                      ),

                      SizedBox(width: 12.s),

                      // Package details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _getPackageTitle(package),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                if (isLifetime) ...[
                                  SizedBox(width: 8.s),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.s,
                                      vertical: 2.s,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFD700),
                                          Color(0xFFFFA500),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'BEST VALUE',
                                      style: GoogleFonts.inter(
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ] else if (isAnnual) ...[
                                  SizedBox(width: 8.s),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.s,
                                      vertical: 2.s,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'SAVE 50%',
                                      style: GoogleFonts.inter(
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 2.s),
                            Text(
                              _getPackageDescription(package),
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Price
                      Text(
                        package.storeProduct.priceString,
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected
                                  ? const Color(0xFFFFD700)
                                  : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: (550 + index * 80).ms, duration: 350.ms)
              .slideX(
                begin: 0.1,
                end: 0,
                delay: (550 + index * 80).ms,
                duration: 350.ms,
              );
        }),
      ],
    );
  }

  String _getPackageTitle(Package package) {
    switch (package.packageType) {
      case PackageType.lifetime:
        return 'Lifetime';
      case PackageType.annual:
        return 'Yearly';
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.weekly:
        return 'Weekly';
      default:
        // Try to extract from identifier
        final id = package.identifier.toLowerCase();
        if (id.contains('lifetime')) return 'Lifetime';
        if (id.contains('year') || id.contains('annual')) return 'Yearly';
        if (id.contains('month')) return 'Monthly';
        if (id.contains('week')) return 'Weekly';
        return package.identifier;
    }
  }

  String _getPackageDescription(Package package) {
    switch (package.packageType) {
      case PackageType.lifetime:
        return 'One-time payment, forever access';
      case PackageType.annual:
        return 'Billed annually';
      case PackageType.monthly:
        return 'Billed monthly';
      case PackageType.weekly:
        return 'Billed weekly';
      default:
        final id = package.identifier.toLowerCase();
        if (id.contains('lifetime')) return 'One-time payment, forever access';
        if (id.contains('year') || id.contains('annual'))
          return 'Billed annually';
        if (id.contains('month')) return 'Billed monthly';
        return 'Auto-renewable subscription';
    }
  }

  Widget _buildLimitedOfferBadge() {
    return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 8.s),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE91E63).withOpacity(0.15),
                const Color(0xFF9C27B0).withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE91E63).withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(3.s),
                decoration: const BoxDecoration(
                  color: Color(0xFFE91E63),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_filled_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              SizedBox(width: 8.s),
              Text(
                'LIMITED TIME',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE91E63),
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(width: 6.s),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.s, vertical: 2.s),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '50% OFF',
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
          color: const Color(0xFFE91E63).withOpacity(0.25),
        );
  }

  Widget _buildBottomActionSection(double bottomPadding) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20.s, 16.s, 20.s, bottomPadding + 16.s),
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
              // PRIMARY: Watch Ad button - Main CTA
              GestureDetector(
                    onTap: _isLoadingAd ? null : _showRewardedAd,
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return AnimatedOpacity(
                          opacity: _isLoadingAd ? 0.7 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: double.infinity,
                            height: 56.s,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4CAF50,
                                  ).withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Shimmer (only show when not loading)
                                if (!_isLoadingAd)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Transform.translate(
                                      offset: Offset(
                                        -200 + (_shimmerController.value * 600),
                                        0,
                                      ),
                                      child: Container(
                                        width: 80,
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
                                      _isLoadingAd
                                          ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 20.s,
                                                height: 20.s,
                                                child:
                                                    const CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.5,
                                                    ),
                                              ),
                                              SizedBox(width: 12.s),
                                              Text(
                                                'Loading Ad...',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                          : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 32.s,
                                                height: 32.s,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                              SizedBox(width: 12.s),
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Continue for Free',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16.sp,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Watch a short video',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.sp,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white
                                                          .withOpacity(0.8),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(width: 12.s),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8.s,
                                                  vertical: 4.s,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '30s',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
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
                  )
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 700.ms, duration: 400.ms),

              SizedBox(height: 12.s),

              // SECONDARY: Premium purchase - smaller, less prominent
              GestureDetector(
                    onTap: _isLoadingPurchase ? null : _purchaseSelectedPackage,
                    child: AnimatedOpacity(
                      opacity: _isLoadingPurchase ? 0.7 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: double.infinity,
                        height: 48.s,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child:
                            _isLoadingPurchase
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18.s,
                                      height: 18.s,
                                      child: const CircularProgressIndicator(
                                        color: Color(0xFFFFD700),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10.s),
                                    Text(
                                      'Processing...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium_rounded,
                                      color: const Color(0xFFFFD700),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8.s),
                                    Text(
                                      'Remove Ads Forever',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    SizedBox(width: 8.s),
                                    Text(
                                      _selectedPackage
                                              ?.storeProduct
                                              .priceString ??
                                          '\$4.99',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFFFD700),
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 800.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 800.ms, duration: 400.ms),

              SizedBox(height: 10.s),

              // Footer links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isLoadingPurchase ? null : _restorePurchases,
                    child: Text(
                      'Restore',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ),
                  Text(
                    '  •  ',
                    style: TextStyle(color: Colors.white.withOpacity(0.3)),
                  ),
                  Text(
                    'Terms',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  Text(
                    '  •  ',
                    style: TextStyle(color: Colors.white.withOpacity(0.3)),
                  ),
                  Text(
                    'Privacy',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.5),
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
