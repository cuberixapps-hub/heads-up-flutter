import 'package:flutter/foundation.dart';
import '../config/environment.dart';
import '../models/deck.dart';
import '../services/ad_service.dart';
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
    if (EnvironmentConfig.enableDebugLogging) {
      debugPrint('🔒 canAccessDeck(${deck.name}): isPremium=$isPremium');
    }
    return isPremium;
  }

  /// Check if user can access a deck by watching an ad
  /// Returns FALSE if:
  /// - Deck is marked as premiumOnly (ads not allowed), OR
  /// - User has reached daily ad limit (max 5 per day)
  /// 
  /// Used to determine if "Watch Ad" option should be shown in paywall
  static bool canAccessDeckWithAdSync(Deck deck) {
    // Premium-only decks cannot be unlocked with ads
    if (deck.premiumOnly) {
      if (EnvironmentConfig.enableDebugLogging) {
        debugPrint('🚫 canAccessDeckWithAd(${deck.name}): premiumOnly=true - ads not allowed');
      }
      return false;
    }
    
    // Check daily ad limit using sync method (cached value)
    final adService = AdService();
    final canWatch = adService.canWatchRewardedAdSync();
    
    if (EnvironmentConfig.enableDebugLogging) {
      final remaining = adService.getRemainingAdsTodaySync();
      debugPrint('📺 canAccessDeckWithAd(${deck.name}): canWatch=$canWatch, remaining=$remaining');
    }
    
    return canWatch;
  }

  /// Async version - Check if user can access a deck by watching an ad
  /// Ensures fresh data from SharedPreferences
  static Future<bool> canAccessDeckWithAd(Deck deck) async {
    // Premium-only decks cannot be unlocked with ads
    if (deck.premiumOnly) {
      return false;
    }
    
    // Check daily ad limit
    final adService = AdService();
    return await adService.canWatchRewardedAd();
  }

  /// Check if user should see paywall for a deck
  /// Returns true if user doesn't have premium AND can't access for free
  static bool shouldShowPaywall(Deck deck) {
    // Premium users skip paywall
    if (hasPremium) return false;
    
    // Free decks don't need paywall
    if (!deck.isPremium) return false;
    
    // Premium deck + free user = show paywall
    return true;
  }

  /// Check if user can access deck through any method (premium, free, or ad)
  /// Useful for determining if gameplay can start
  static bool canPlayDeck(Deck deck) {
    // Premium users can play any deck
    if (hasPremium) return true;
    
    // Free decks are always playable
    if (!deck.isPremium) return true;
    
    // Premium deck + free user: they need to go through paywall
    return false;
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

  /// Check if active plan is a weekend pass (48-hour, non-renewing)
  static bool get isWeekendPass => PurchasesService().isWeekendPass;

  /// Time remaining on weekend pass (Duration.zero if not active)
  static Duration get weekendPassTimeRemaining => PurchasesService().weekendPassTimeRemaining;

  /// Get subscription expiration date (null for lifetime or free users)
  static DateTime? get expirationDate => PurchasesService().subscriptionExpirationDate;

  /// Check if subscription will auto-renew
  static bool get willRenew => PurchasesService().willRenew;

  /// Check if user is in trial period
  static bool get isInTrial => PurchasesService().isInTrialPeriod;
}

