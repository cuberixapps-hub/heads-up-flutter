import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
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
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for the icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fade animation for the overlay
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
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
      _fadeController.forward();
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final isOffline = result.contains(ConnectivityResult.none) || result.isEmpty;
    if (_isOffline != isOffline) {
      setState(() {
        _isOffline = isOffline;
        _isChecking = false;
      });
      if (_isOffline) {
        _fadeController.forward();
      } else {
        _fadeController.reverse();
      }
    }
  }

  Future<void> _retryConnection() async {
    setState(() {
      _isChecking = true;
    });
    
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Could not check connectivity: $e');
    }
    
    setState(() {
      _isChecking = false;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
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
    
    // Fallback texts if localization is not available
    final noInternetTitle = l10n?.noInternetTitle ?? 'No Internet Connection';
    final noInternetDescription = l10n?.noInternetDescription ?? 
        'Please check your internet connection and try again. This app requires an active internet connection to work.';
    final tryAgainButton = l10n?.tryAgainButton ?? 'Try Again';
    final checkingConnection = l10n?.checkingConnection ?? 'Checking...';
    final tipsToReconnect = l10n?.tipsToReconnect ?? 'Tips to reconnect:';
    final tipEnableWifi = l10n?.tipEnableWifi ?? 'Check if WiFi is enabled';
    final tipTryMobileData = l10n?.tipTryMobileData ?? 'Try switching to mobile data';
    final tipMoveCloser = l10n?.tipMoveCloser ?? 'Move closer to your router';
    final tipRestartDevice = l10n?.tipRestartDevice ?? 'Restart your device';
    
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkPrimary,
            AppTheme.darkSecondary,
            AppTheme.darkAccent.withOpacity(0.9),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated WiFi Off Icon
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red.shade400.withOpacity(0.3),
                          Colors.orange.shade400.withOpacity(0.3),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.red.shade400.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade400.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: 70,
                      color: Colors.red.shade300,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Title
                Text(
                  noInternetTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                Text(
                  noInternetDescription,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.6,
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Retry Button
                GestureDetector(
                  onTap: _isChecking ? null : _retryConnection,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isChecking 
                          ? [Colors.grey.shade600, Colors.grey.shade700]
                          : [AppTheme.primaryColor, AppTheme.primaryColor.withBlue(255)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: _isChecking ? [] : [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isChecking)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else
                          const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        const SizedBox(width: 12),
                        Text(
                          _isChecking ? checkingConnection : tryAgainButton,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Helpful tips
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: AppTheme.warningColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tipsToReconnect,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTipItem(tipEnableWifi),
                      _buildTipItem(tipTryMobileData),
                      _buildTipItem(tipMoveCloser),
                      _buildTipItem(tipRestartDevice),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.6),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
