import 'package:flutter/foundation.dart';
import '../models/deck.dart';
import '../services/purchases_service.dart';

/// Utility class for premium content access checks
/// Use these helpers throughout the app for consistent premium gating
/// 
/// IMPORTANT: All methods return FALSE (free user behavior) by default.
/// Premium status is only granted when:
/// 1. Debug simulation is enabled via Settings toggle (debug mode only), OR
/// 2. RevenueCat confirms user has active premium entitlement
class PremiumUtils {
  PremiumUtils._(); // Private constructor - use static methods only

  /// Check if user can access a specific deck
  /// Returns true if:
  /// - The deck is free (not premium), OR
  /// - The user has an active premium subscription/purchase
  static bool canAccessDeck(Deck deck) {
    // Free decks are accessible to everyone
    if (!deck.isPremium) return true;
    
    // Premium decks require premium status
    final isPremium = PurchasesService().isPremium;
    if (kDebugMode) {
      debugPrint('🔒 canAccessDeck(${deck.name}): isPremium=$isPremium');
    }
    return isPremium;
  }

  /// Check if ads should be shown to the user
  /// Returns TRUE by default (show ads to free users)
  /// Returns FALSE only if user has verified premium status
  static bool shouldShowAds() {
    final isPremium = PurchasesService().isPremium;
    // Show ads if NOT premium
    return !isPremium;
  }

  /// Check if user has premium access
  /// Returns FALSE by default (free user behavior)
  /// Convenience getter that delegates to PurchasesService
  static bool get hasPremium => PurchasesService().isPremium;

  /// Get the current plan name for display
  static String get currentPlanName => PurchasesService().activePlanName;

  /// Check if user's subscription is lifetime (never expires)
  static bool get isLifetimePlan => PurchasesService().isLifetime;

  /// Get subscription expiration date (null for lifetime or free users)
  static DateTime? get expirationDate => PurchasesService().subscriptionExpirationDate;

  /// Check if subscription will auto-renew
  static bool get willRenew => PurchasesService().willRenew;

  /// Check if user is in trial period
  static bool get isInTrial => PurchasesService().isInTrialPeriod;
}

