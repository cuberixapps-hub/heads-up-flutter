import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math' as math;
import '../constants/app_theme.dart';
import '../l10n/app_localizations.dart';

class NetworkStatusWidget extends StatefulWidget {
  final Widget child;

  const NetworkStatusWidget({super.key, required this.child});

  @override
  State<NetworkStatusWidget> createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget>
    with TickerProviderStateMixin {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;
  bool _isChecking = false;
  bool _showTips = false;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late AnimationController _staggerController;
  late AnimationController _buttonController;
  late AnimationController _rotateController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _titleAnimation;
  late Animation<double> _descriptionAnimation;
  late Animation<double> _buttonAnimation;
  late Animation<double> _tipsAnimation;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  void _initAnimations() {
    // Fade animation for the overlay
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    // Gentle floating animation for the icon
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // Stagger animation for content elements
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    _titleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _descriptionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _tipsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Button press animation
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    // Rotation animation for refresh icon
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Could not check connectivity: $e');
      setState(() {
        _isOffline = true;
      });
      _showOverlay();
    }
  }

  void _showOverlay() {
    _fadeController.forward();
    _staggerController.forward();
  }

  void _hideOverlay() {
    _fadeController.reverse().then((_) {
      _staggerController.reset();
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final isOffline = result.contains(ConnectivityResult.none) || result.isEmpty;
    if (_isOffline != isOffline) {
      setState(() {
        _isOffline = isOffline;
        _isChecking = false;
      });
      if (_isOffline) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    }
  }

  Future<void> _retryConnection() async {
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() {
      _isChecking = true;
    });
    
    // Start rotation animation
    _rotateController.repeat();
    
    try {
      // Simulate a small delay for better UX
      await Future.delayed(const Duration(milliseconds: 800));
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Could not check connectivity: $e');
    }
    
    _rotateController.stop();
    _rotateController.reset();
    
    setState(() {
      _isChecking = false;
    });
  }

  void _toggleTips() {
    HapticFeedback.selectionClick();
    setState(() {
      _showTips = !_showTips;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _fadeController.dispose();
    _floatController.dispose();
    _staggerController.dispose();
    _buttonController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              );
            },
            child: _buildNoInternetOverlay(context),
          ),
      ],
    );
  }

  Widget _buildNoInternetOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context);
    
    // Fallback texts
    final noInternetTitle = l10n?.noInternetTitle ?? 'No Internet Connection';
    final noInternetDescription = l10n?.noInternetDescription ?? 
        'Please check your connection and try again';
    final tryAgainButton = l10n?.tryAgainButton ?? 'Try Again';
    final checkingConnection = l10n?.checkingConnection ?? 'Checking...';
    final tipsToReconnect = l10n?.tipsToReconnect ?? 'Troubleshooting tips';
    final tipEnableWifi = l10n?.tipEnableWifi ?? 'Check if WiFi is enabled';
    final tipTryMobileData = l10n?.tipTryMobileData ?? 'Try switching to mobile data';
    final tipMoveCloser = l10n?.tipMoveCloser ?? 'Move closer to your router';
    final tipRestartDevice = l10n?.tipRestartDevice ?? 'Restart your device';
    
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: size.width,
        height: size.height,
        color: const Color(0xFF0D1117),
        child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  
                  // Animated Icon with floating effect
                  AnimatedBuilder(
                    animation: Listenable.merge([_iconScaleAnimation, _floatAnimation]),
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnimation.value * _iconScaleAnimation.value),
                        child: Transform.scale(
                          scale: _iconScaleAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildIconWidget(),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Title with fade-slide animation
                  AnimatedBuilder(
                    animation: _titleAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - _titleAnimation.value)),
                        child: Opacity(
                          opacity: _titleAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      noInternetTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // Description with fade-slide animation
                  AnimatedBuilder(
                    animation: _descriptionAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - _descriptionAnimation.value)),
                        child: Opacity(
                          opacity: _descriptionAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      noInternetDescription,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF8B949E),
                        height: 1.5,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 44),
                  
                  // Retry Button with scale animation
                  AnimatedBuilder(
                    animation: Listenable.merge([_buttonAnimation, _buttonScaleAnimation]),
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - _buttonAnimation.value)),
                        child: Opacity(
                          opacity: _buttonAnimation.value,
                          child: Transform.scale(
                            scale: _buttonScaleAnimation.value,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _buildRetryButton(tryAgainButton, checkingConnection),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Expandable Tips Section
                  AnimatedBuilder(
                    animation: _tipsAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - _tipsAnimation.value)),
                        child: Opacity(
                          opacity: _tipsAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildTipsSection(
                      tipsToReconnect,
                      [tipEnableWifi, tipTryMobileData, tipMoveCloser, tipRestartDevice],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildIconWidget() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF21262D),
                width: 1.5,
              ),
            ),
          ),
          // Icon
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: const Color(0xFFF87171),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryButton(String tryAgainText, String checkingText) {
    return GestureDetector(
      onTapDown: (_) => _buttonController.forward(),
      onTapUp: (_) {
        _buttonController.reverse();
        if (!_isChecking) _retryConnection();
      },
      onTapCancel: () => _buttonController.reverse(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: _isChecking 
              ? const Color(0xFF21262D) 
              : AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isChecking ? [] : [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _rotateController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotateController.value * 2 * math.pi,
                  child: child,
                );
              },
              child: Icon(
                _isChecking ? Icons.sync_rounded : Icons.refresh_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _isChecking ? checkingText : tryAgainText,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsSection(String title, List<String> tips) {
    return Column(
      children: [
        // Toggle button
        GestureDetector(
          onTap: _toggleTips,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  color: const Color(0xFF8B949E),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8B949E),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: _showTips ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8B949E),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Expandable tips list
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _showTips ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF21262D),
                  width: 1,
                ),
              ),
              child: Column(
                children: tips.asMap().entries.map((entry) {
                  return _buildTipItem(entry.value, entry.key, tips.length);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String text, int index, int total) {
    final icons = [
      Icons.wifi_rounded,
      Icons.swap_horiz_rounded,
      Icons.near_me_outlined,
      Icons.restart_alt_rounded,
    ];
    
    return Padding(
      padding: EdgeInsets.only(bottom: index < total - 1 ? 16 : 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icons[index % icons.length],
              color: const Color(0xFF8B949E),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFC9D1D9),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
