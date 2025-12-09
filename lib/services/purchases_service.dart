import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'firebase_service.dart';

/// RevenueCat Purchase Service
/// Handles all in-app purchase and subscription logic
class PurchasesService {
  static final PurchasesService _instance = PurchasesService._internal();
  factory PurchasesService() => _instance;
  PurchasesService._internal();

  static bool _initialized = false;

  // ============================================
  // 🔑 REVENUECAT API KEYS - REPLACE WITH YOUR KEYS
  // ============================================
  // Get these from: https://app.revenuecat.com/
  // Project Settings → API Keys
  static const String _androidApiKey = 'YOUR_ANDROID_API_KEY';
  static const String _iosApiKey = 'YOUR_IOS_API_KEY';

  // ============================================
  // 📦 ENTITLEMENT & PRODUCT IDS
  // ============================================
  // These must match what you configure in RevenueCat dashboard
  // and App Store Connect / Google Play Console
  static const String entitlementId = 'premium';
  static const String productIdMonthly = 'premium_monthly';
  static const String productIdYearly = 'premium_yearly';
  static const String productIdLifetime = 'premium_lifetime';

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

  /// Check if RevenueCat is initialized
  static bool get isInitialized => _initialized;

  /// Check if user has premium access
  bool get isPremium => _isPremium;

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

    try {
      // Configure RevenueCat
      final configuration = PurchasesConfiguration(
        Platform.isIOS ? _iosApiKey : _androidApiKey,
      );

      await Purchases.configure(configuration);

      // Enable debug logs in development
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      _initialized = true;
      debugPrint('✅ RevenueCat SDK initialized');
      debugPrint('📱 Platform: ${Platform.isIOS ? "iOS" : "Android"}');

      // Fetch initial customer info and offerings
      final instance = PurchasesService();
      await instance._fetchCustomerInfo();
      await instance._fetchOfferings();

      // Set up listener for customer info updates
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
  DateTime? get subscriptionExpirationDate {
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

  /// Identify user (call after user logs in)
  Future<void> identifyUser(String userId) async {
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

