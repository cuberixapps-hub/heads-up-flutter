import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import '../config/purchase_config.dart';
import 'firebase_service.dart';

/// RevenueCat Purchase Service
/// Handles all in-app purchase and subscription logic
class PurchasesService {
  static final PurchasesService _instance = PurchasesService._internal();
  factory PurchasesService() => _instance;
  PurchasesService._internal();

  static bool _initialized = false;

  // ============================================
  // 📦 ENTITLEMENT & PRODUCT IDS
  // ============================================
  // These must match what you configure in RevenueCat dashboard
  // and App Store Connect / Google Play Console
  static const String entitlementId = 'premium';
  static const String productIdMonthly = 'premium_monthly';
  static const String productIdYearly = 'premium_yearly';
  static const String productIdLifetime = 'premium_lifetime';
  static const String productIdWeekend = 'premium_weekend';

  // ============================================
  // 🎉 WEEKEND PASS - 48-Hour One-Time Purchase
  // ============================================
  // Tracked locally because the product is a non-renewing subscription
  // and we need precise 48-hour expiry (stores only offer fixed periods).
  // Purchase timestamp is persisted in SharedPreferences (UTC) so it
  // survives app restarts and works correctly across time zones.
  static const Duration weekendPassDuration = Duration(hours: 48);
  static const String _weekendPassExpiryKey = 'weekend_pass_expiry_utc';
  DateTime? _weekendPassExpiry;
  Timer? _weekendPassTimer;

  // ============================================
  // 📊 STATE MANAGEMENT
  // ============================================
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  bool _isPremium = false;

  // Stream controller for premium status changes
  final StreamController<bool> _premiumStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  // ============================================
  // 🧪 DEBUG MODE - For Testing Only
  // ============================================
  /// DEBUG ONLY: Simulate premium purchase for testing UI/UX
  /// This does NOT actually grant premium - only for UI testing
  /// Can ONLY be toggled via Settings screen debug controls
  static bool _debugSimulatePremium = false;

  /// Enable simulated premium status (development only)
  /// Call this ONLY from Settings screen debug toggle
  static void debugEnablePremium() {
    if (EnvironmentConfig.isDevelopment) {
      _debugSimulatePremium = true;
      debugPrint('🧪 DEBUG: Simulating premium status via Settings toggle');
      PurchasesService()._premiumStatusController.add(true);
    }
  }

  /// Disable simulated premium status (development only)
  /// Call this ONLY from Settings screen debug toggle
  static void debugDisablePremium() {
    if (EnvironmentConfig.isDevelopment) {
      _debugSimulatePremium = false;
      debugPrint('🧪 DEBUG: Disabling simulated premium via Settings toggle');
      PurchasesService()._premiumStatusController.add(false);
    }
  }

  /// Check if debug simulation is active (development only)
  static bool get isDebugPremiumActive =>
      EnvironmentConfig.isDevelopment && _debugSimulatePremium;

  /// Check if RevenueCat is initialized
  static bool get isInitialized => _initialized;

  /// Check if user has premium access
  /// Returns true ONLY if:
  /// 1. Debug simulation is enabled via Settings toggle (debug mode only), OR
  /// 2. RevenueCat confirms user has active premium entitlement, OR
  /// 3. An active Weekend Pass is still within its 48-hour window
  /// 
  /// IMPORTANT: Returns FALSE by default for all users until proven otherwise
  bool get isPremium {
    // Debug simulation - ONLY works in development when explicitly enabled via Settings toggle
    if (EnvironmentConfig.isDevelopment && _debugSimulatePremium) {
      return true;
    }

    // Weekend Pass: local 48-hour timer (works even if RevenueCat not initialized)
    if (isWeekendPassActive) {
      return true;
    }
    
    // If RevenueCat not properly initialized, user is FREE (show ads)
    if (!_initialized) {
      return false;
    }
    
    // Return actual premium status from RevenueCat
    return _isPremium;
  }

  /// Get current offerings (products available for purchase)
  Offerings? get offerings => _offerings;

  /// Get current customer info
  CustomerInfo? get customerInfo => _customerInfo;

  /// Initialize RevenueCat SDK
  /// Call this in main.dart after Firebase initialization
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️ RevenueCat already initialized');
      return;
    }

    final String apiKey = PurchaseConfig.apiKey;
    if (PurchaseConfig.isPlaceholder) {
      debugPrint('⚠️ RevenueCat: Placeholder API key - treating all users as FREE');
      return;
    }

    try {
      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);

      // Use LogLevel.warn in dev to avoid massive JWT token dumps in console.
      // RevenueCat's debug level prints full StoreKit transaction receipts.
      if (EnvironmentConfig.enableDebugLogging) {
        await Purchases.setLogLevel(LogLevel.warn);
      } else {
        await Purchases.setLogLevel(LogLevel.info);
      }

      _initialized = true;
      debugPrint('✅ RevenueCat SDK initialized');
      debugPrint('📱 Platform: ${Platform.isIOS ? "iOS" : "Android"}');

      final instance = PurchasesService();
      await instance._restoreWeekendPass();
      await instance._fetchCustomerInfo();
      await instance._fetchOfferings();
      debugPrint('📊 Initial premium status: ${instance._isPremium}');

      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        instance._handleCustomerInfoUpdate(customerInfo);
      });
    } catch (e, stackTrace) {
      debugPrint('❌ RevenueCat initialization failed: $e');
      FirebaseService.logError(e, stackTrace);
    }
  }

  /// Handle customer info updates
  void _handleCustomerInfoUpdate(CustomerInfo info) {
    _customerInfo = info;
    final wasPremium = _isPremium;
    _isPremium = info.entitlements.active.containsKey(entitlementId);

    if (wasPremium != _isPremium) {
      debugPrint('🔄 Premium status changed: $_isPremium');
      _premiumStatusController.add(_isPremium);

      // Log analytics event
      FirebaseService().logEvent(
        'premium_status_changed',
        parameters: {'is_premium': _isPremium},
      );
    }
  }

  /// Fetch customer info from RevenueCat
  Future<void> _fetchCustomerInfo() async {
    // Guard: Don't call SDK if not initialized (prevents fatal crash)
    if (!_initialized) {
      debugPrint('⚠️ RevenueCat not initialized - skipping customer info fetch');
      return;
    }
    
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      _isPremium =
          _customerInfo?.entitlements.active.containsKey(entitlementId) ??
              false;
      debugPrint('📊 Customer info fetched. Premium: $_isPremium');
    } catch (e) {
      debugPrint('❌ Failed to fetch customer info: $e');
    }
  }

  /// Fetch available offerings (products)
  Future<void> _fetchOfferings() async {
    // Guard: Don't call SDK if not initialized (prevents fatal crash)
    if (!_initialized) {
      debugPrint('⚠️ RevenueCat not initialized - skipping offerings fetch');
      return;
    }
    
    try {
      _offerings = await Purchases.getOfferings();
      if (_offerings?.current != null) {
        debugPrint('📦 Offerings loaded:');
        for (var package in _offerings!.current!.availablePackages) {
          debugPrint(
            '   - ${package.identifier}: ${package.storeProduct.priceString}',
          );
        }
      } else {
        debugPrint('⚠️ No offerings available');
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch offerings: $e');
    }
  }

  /// Refresh offerings (call when paywall opens)
  Future<Offerings?> refreshOfferings() async {
    // Guard: Don't call SDK if not initialized (prevents fatal crash)
    if (!_initialized) {
      debugPrint('⚠️ RevenueCat not initialized - no offerings available');
      return null;
    }
    
    await _fetchOfferings();
    return _offerings;
  }

  /// Get the current offering
  Offering? get currentOffering => _offerings?.current;

  /// Get available packages from current offering
  List<Package> get availablePackages =>
      currentOffering?.availablePackages ?? [];

  /// Get a specific package by type
  Package? getPackage(PackageType type) {
    switch (type) {
      case PackageType.monthly:
        return currentOffering?.monthly;
      case PackageType.annual:
        return currentOffering?.annual;
      case PackageType.lifetime:
        return currentOffering?.lifetime;
      default:
        return null;
    }
  }

  /// Purchase a package
  Future<PurchaseResult> purchasePackage(Package package) async {
    // Guard: Don't call SDK if not initialized (prevents fatal crash)
    if (!_initialized) {
      debugPrint('⚠️ RevenueCat not initialized - cannot purchase');
      return PurchaseResult.notAllowed;
    }
    
    try {
      debugPrint('🛒 Attempting to purchase: ${package.identifier}');

      final customerInfo = await Purchases.purchasePackage(package);
      _handleCustomerInfoUpdate(customerInfo);

      if (_isPremium) {
        debugPrint('✅ Purchase successful! User is now premium');

        // Log analytics
        FirebaseService().logEvent(
          'purchase_completed',
          parameters: {
            'product_id': package.storeProduct.identifier,
            'price': package.storeProduct.price,
            'currency': package.storeProduct.currencyCode,
          },
        );

        return PurchaseResult.success;
      } else {
        debugPrint('⚠️ Purchase completed but entitlement not found');
        return PurchaseResult.pending;
      }
    } on PurchasesErrorCode catch (e) {
      debugPrint('❌ Purchase error code: $e');
      return _handlePurchaseError(e);
    } catch (e) {
      debugPrint('❌ Purchase failed: $e');
      return PurchaseResult.error;
    }
  }

  /// Handle purchase errors
  PurchaseResult _handlePurchaseError(PurchasesErrorCode errorCode) {
    switch (errorCode) {
      case PurchasesErrorCode.purchaseCancelledError:
        debugPrint('ℹ️ User cancelled purchase');
        return PurchaseResult.cancelled;
      case PurchasesErrorCode.purchaseNotAllowedError:
        debugPrint('⚠️ Purchase not allowed');
        return PurchaseResult.notAllowed;
      case PurchasesErrorCode.purchaseInvalidError:
        debugPrint('⚠️ Invalid purchase');
        return PurchaseResult.invalid;
      case PurchasesErrorCode.productAlreadyPurchasedError:
        debugPrint('ℹ️ Product already purchased');
        return PurchaseResult.alreadyOwned;
      case PurchasesErrorCode.networkError:
        debugPrint('⚠️ Network error during purchase');
        return PurchaseResult.networkError;
      default:
        debugPrint('⚠️ Unknown purchase error: $errorCode');
        return PurchaseResult.error;
    }
  }

  /// Restore purchases
  Future<RestoreResult> restorePurchases() async {
    // Guard: Don't call SDK if not initialized (prevents fatal crash)
    if (!_initialized) {
      debugPrint('⚠️ RevenueCat not initialized - cannot restore purchases');
      return RestoreResult.error;
    }
    
    try {
      debugPrint('🔄 Restoring purchases...');

      final customerInfo = await Purchases.restorePurchases();
      _handleCustomerInfoUpdate(customerInfo);

      if (_isPremium) {
        debugPrint('✅ Purchases restored! User is premium');

        FirebaseService().logEvent(
          'purchases_restored',
          parameters: {'is_premium': true},
        );

        return RestoreResult.success;
      } else {
        debugPrint('ℹ️ No purchases to restore');
        return RestoreResult.noPurchases;
      }
    } on PurchasesErrorCode catch (e) {
      debugPrint('❌ Restore error: $e');
      if (e == PurchasesErrorCode.networkError) {
        return RestoreResult.networkError;
      }
      return RestoreResult.error;
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
      return RestoreResult.error;
    }
  }

  /// Check subscription status
  Future<bool> checkPremiumStatus() async {
    await _fetchCustomerInfo();
    return _isPremium;
  }

  /// Get subscription expiration date (if applicable)
  /// Returns the weekend pass expiry if active, otherwise RevenueCat's date
  DateTime? get subscriptionExpirationDate {
    // Weekend pass expiry (locally managed)
    if (isWeekendPassActive) return _weekendPassExpiry;

    final entitlement = _customerInfo?.entitlements.active[entitlementId];
    if (entitlement?.expirationDate != null) {
      return DateTime.parse(entitlement!.expirationDate!);
    }
    return null;
  }

  /// Check if subscription is in trial period
  bool get isInTrialPeriod {
    final entitlement = _customerInfo?.entitlements.active[entitlementId];
    return entitlement?.periodType == PeriodType.trial;
  }

  /// Check if subscription will renew
  bool get willRenew {
    final entitlement = _customerInfo?.entitlements.active[entitlementId];
    return entitlement?.willRenew ?? false;
  }

  /// Get the active product identifier
  String? get activeProductId {
    final entitlement = _customerInfo?.entitlements.active[entitlementId];
    return entitlement?.productIdentifier;
  }

  /// Get the active plan name for display
  String get activePlanName {
    if (EnvironmentConfig.isDevelopment && _debugSimulatePremium) {
      return 'Debug Premium';
    }

    // Local weekend pass takes priority (non-renewing, app-managed)
    if (isWeekendPassActive) return 'Weekend Pass';
    
    final productId = activeProductId;
    if (productId == null) return 'Free';
    
    if (productId.contains('lifetime')) return 'Lifetime';
    if (productId.contains('yearly') || productId.contains('annual')) return 'Annual';
    if (productId.contains('monthly')) return 'Monthly';
    if (productId.contains('weekend')) return 'Weekend Pass';
    
    return 'Premium';
  }

  /// Check if subscription is lifetime (non-expiring)
  bool get isLifetime {
    final productId = activeProductId;
    return productId?.contains('lifetime') ?? false;
  }

  /// Check if active plan is a weekend pass (48-hour non-renewing)
  bool get isWeekendPass {
    final productId = activeProductId;
    if (productId?.contains('weekend') ?? false) return true;
    // Also check local timer (product may no longer appear in active entitlements)
    return isWeekendPassActive;
  }

  // ============================================
  // 🎉 WEEKEND PASS - 48-Hour Timer Management
  // ============================================

  /// Whether the locally-tracked weekend pass is still within its 48-hour window
  bool get isWeekendPassActive {
    if (_weekendPassExpiry == null) return false;
    return DateTime.now().toUtc().isBefore(_weekendPassExpiry!);
  }

  /// Time remaining on the weekend pass (Duration.zero if expired/inactive)
  Duration get weekendPassTimeRemaining {
    if (_weekendPassExpiry == null) return Duration.zero;
    final remaining = _weekendPassExpiry!.difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get weekend pass expiry date (null if not active)
  DateTime? get weekendPassExpiryDate => isWeekendPassActive ? _weekendPassExpiry : null;

  /// Activate the weekend pass after a successful purchase.
  /// Saves the expiry timestamp to SharedPreferences (UTC) and starts
  /// a timer that automatically revokes premium when 48 hours elapse.
  Future<void> activateWeekendPass() async {
    final now = DateTime.now().toUtc();
    _weekendPassExpiry = now.add(weekendPassDuration);

    // Persist to SharedPreferences so it survives app restarts
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_weekendPassExpiryKey, _weekendPassExpiry!.toIso8601String());
      debugPrint('🎉 Weekend Pass activated! Expires: $_weekendPassExpiry');
    } catch (e) {
      debugPrint('❌ Failed to save weekend pass expiry: $e');
    }

    // Notify listeners that premium is now active
    _premiumStatusController.add(true);

    // Schedule automatic expiry
    _scheduleWeekendPassExpiry();

    // Log analytics
    FirebaseService().logEvent(
      'weekend_pass_activated',
      parameters: {
        'expiry_utc': _weekendPassExpiry!.toIso8601String(),
        'duration_hours': weekendPassDuration.inHours,
      },
    );
  }

  /// Restore weekend pass state from SharedPreferences on app launch.
  /// Called during initialize() to resume an active pass after restart.
  Future<void> _restoreWeekendPass() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryString = prefs.getString(_weekendPassExpiryKey);
      if (expiryString == null) return;

      final expiry = DateTime.parse(expiryString);
      final now = DateTime.now().toUtc();

      if (now.isBefore(expiry)) {
        // Still active — restore and schedule expiry
        _weekendPassExpiry = expiry;
        _scheduleWeekendPassExpiry();
        debugPrint('🎉 Weekend Pass restored! Remaining: ${weekendPassTimeRemaining.inMinutes} min');
      } else {
        // Already expired — clean up
        await prefs.remove(_weekendPassExpiryKey);
        _weekendPassExpiry = null;
        debugPrint('⏰ Weekend Pass expired during app restart — cleaned up');
      }
    } catch (e) {
      debugPrint('❌ Failed to restore weekend pass: $e');
    }
  }

  /// Schedule a timer that fires when the weekend pass expires,
  /// updating premium status automatically without needing a server call.
  void _scheduleWeekendPassExpiry() {
    _weekendPassTimer?.cancel();

    if (_weekendPassExpiry == null) return;

    final remaining = _weekendPassExpiry!.difference(DateTime.now().toUtc());
    if (remaining.isNegative) {
      _onWeekendPassExpired();
      return;
    }

    _weekendPassTimer = Timer(remaining, _onWeekendPassExpired);
    debugPrint('⏰ Weekend Pass expiry timer set: ${remaining.inMinutes} min');
  }

  /// Called when the 48-hour window elapses.
  Future<void> _onWeekendPassExpired() async {
    _weekendPassExpiry = null;
    _weekendPassTimer?.cancel();
    _weekendPassTimer = null;

    // Clean up persisted data
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_weekendPassExpiryKey);
    } catch (_) {}

    // Re-evaluate premium: if no other entitlement is active, user is free
    final stillPremium = _isPremium; // from RevenueCat
    _premiumStatusController.add(stillPremium);

    debugPrint('⏰ Weekend Pass expired. Premium from RevenueCat: $stillPremium');

    FirebaseService().logEvent('weekend_pass_expired');
  }

  /// Identify user (call after user logs in)
  Future<void> identifyUser(String userId) async {
    // Guard: Don't call SDK if not initialized (prevents fatal crash)
    if (!_initialized) {
      debugPrint('⚠️ RevenueCat not initialized - skipping user identification');
      return;
    }
    
    try {
      final result = await Purchases.logIn(userId);
      _handleCustomerInfoUpdate(result.customerInfo);
      debugPrint('✅ User identified: $userId');
    } catch (e) {
      debugPrint('❌ Failed to identify user: $e');
    }
  }

  /// Reset user (call after user logs out)
  Future<void> resetUser() async {
    // Guard: Don't call SDK if not initialized (prevents fatal crash)
    if (!_initialized) {
      debugPrint('⚠️ RevenueCat not initialized - skipping user reset');
      return;
    }
    
    try {
      final customerInfo = await Purchases.logOut();
      _handleCustomerInfoUpdate(customerInfo);
      debugPrint('✅ User logged out from RevenueCat');
    } catch (e) {
      debugPrint('❌ Failed to log out user: $e');
    }
  }

  /// Set user attributes for analytics
  Future<void> setUserAttributes({
    String? email,
    String? displayName,
    String? phoneNumber,
    Map<String, String>? customAttributes,
  }) async {
    // Guard: Don't call SDK if not initialized (prevents fatal crash)
    if (!_initialized) {
      debugPrint('⚠️ RevenueCat not initialized - skipping user attributes');
      return;
    }
    
    try {
      if (email != null) {
        await Purchases.setEmail(email);
      }
      if (displayName != null) {
        await Purchases.setDisplayName(displayName);
      }
      if (phoneNumber != null) {
        await Purchases.setPhoneNumber(phoneNumber);
      }
      if (customAttributes != null) {
        for (var entry in customAttributes.entries) {
          await Purchases.setAttributes({entry.key: entry.value});
        }
      }
      debugPrint('✅ User attributes set');
    } catch (e) {
      debugPrint('❌ Failed to set user attributes: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _weekendPassTimer?.cancel();
    _premiumStatusController.close();
  }
}

/// Purchase result enum
enum PurchaseResult {
  success,
  cancelled,
  pending,
  error,
  notAllowed,
  invalid,
  alreadyOwned,
  networkError,
}

/// Restore result enum
enum RestoreResult {
  success,
  noPurchases,
  error,
  networkError,
}

/// Extension to get user-friendly messages
extension PurchaseResultMessage on PurchaseResult {
  String get message {
    switch (this) {
      case PurchaseResult.success:
        return 'Purchase successful! You now have premium access.';
      case PurchaseResult.cancelled:
        return 'Purchase cancelled.';
      case PurchaseResult.pending:
        return 'Purchase is pending. Please wait...';
      case PurchaseResult.notAllowed:
        return 'Purchase not allowed on this device.';
      case PurchaseResult.invalid:
        return 'Invalid purchase. Please try again.';
      case PurchaseResult.alreadyOwned:
        return 'You already own this product!';
      case PurchaseResult.networkError:
        return 'Network error. Please check your connection.';
      case PurchaseResult.error:
        return 'Something went wrong. Please try again.';
    }
  }
}

extension RestoreResultMessage on RestoreResult {
  String get message {
    switch (this) {
      case RestoreResult.success:
        return 'Purchases restored successfully!';
      case RestoreResult.noPurchases:
        return 'No previous purchases found.';
      case RestoreResult.networkError:
        return 'Network error. Please check your connection.';
      case RestoreResult.error:
        return 'Failed to restore purchases. Please try again.';
    }
  }
}

