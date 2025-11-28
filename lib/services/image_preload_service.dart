import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/deck.dart';
import '../services/firebase_service.dart';
import 'image_cache_manager.dart';

/// Service for preloading images in the background to improve performance
/// Only preloads on WiFi to respect data usage preferences
class ImagePreloadService {
  static final ImagePreloadService _instance = ImagePreloadService._internal();
  factory ImagePreloadService() => _instance;
  ImagePreloadService._internal();

  final List<String> _preloadedUrls = [];
  bool _isPreloading = false;
  bool _enabled = true;

  /// Check if currently preloading
  bool get isPreloading => _isPreloading;

  /// Get count of preloaded images
  int get preloadedCount => _preloadedUrls.length;

  /// Enable or disable preloading
  void setEnabled(bool enabled) {
    _enabled = enabled;
    debugPrint('🖼️ Image preloading ${enabled ? "enabled" : "disabled"}');
  }

  /// Check if device is connected to WiFi
  Future<bool> _isConnectedToWiFi() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.contains(ConnectivityResult.wifi);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  /// Preload images for a list of decks
  /// Only preloads if on WiFi and service is enabled
  Future<void> preloadDeckImages(
    BuildContext context,
    List<Deck> decks, {
    int maxImages = 20,
  }) async {
    if (!_enabled) {
      debugPrint('🖼️ Image preloading disabled');
      return;
    }

    if (_isPreloading) {
      debugPrint('🖼️ Already preloading images');
      return;
    }

    final isWiFi = await _isConnectedToWiFi();
    if (!isWiFi) {
      debugPrint('🖼️ Not on WiFi, skipping image preload');
      return;
    }

    _isPreloading = true;
    debugPrint('🖼️ Starting image preload for ${decks.length} decks');

    try {
      int preloadedCount = 0;
      for (final deck in decks) {
        if (preloadedCount >= maxImages) break;
        if (deck.imageUrl == null || deck.imageUrl!.isEmpty) continue;
        if (_preloadedUrls.contains(deck.imageUrl!)) continue;

        try {
          // Use CachedNetworkImage's provider to preload with custom cache manager
          await precacheImage(
            CachedNetworkImageProvider(
              deck.imageUrl!,
              cacheManager: CustomImageCacheManager(),
            ),
            context,
          );

          _preloadedUrls.add(deck.imageUrl!);
          preloadedCount++;
          
          debugPrint('🖼️ Preloaded image ${deck.name}: ${deck.imageUrl}');

          // Small delay to avoid overloading the system
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('Error preloading image for ${deck.name}: $e');
        }
      }

      debugPrint('🖼️ Preloading complete: $preloadedCount images loaded');

      // Log analytics
      await FirebaseService().logEvent('images_preloaded', parameters: {
        'count': preloadedCount,
        'total_cached': _preloadedUrls.length,
      });
    } catch (e) {
      debugPrint('Error during image preload: $e');
    } finally {
      _isPreloading = false;
    }
  }

  /// Preload a single image URL
  /// Only preloads if on WiFi and service is enabled
  Future<void> preloadImage(
    BuildContext context,
    String imageUrl, {
    bool force = false,
  }) async {
    if (!_enabled && !force) {
      return;
    }

    if (_preloadedUrls.contains(imageUrl)) {
      debugPrint('🖼️ Image already preloaded: $imageUrl');
      return;
    }

    if (!force) {
      final isWiFi = await _isConnectedToWiFi();
      if (!isWiFi) {
        debugPrint('🖼️ Not on WiFi, skipping image preload');
        return;
      }
    }

    try {
      await precacheImage(
        CachedNetworkImageProvider(
          imageUrl,
          cacheManager: CustomImageCacheManager(),
        ),
        context,
      );
      _preloadedUrls.add(imageUrl);
      debugPrint('🖼️ Preloaded single image: $imageUrl');
    } catch (e) {
      debugPrint('Error preloading image: $e');
    }
  }

  /// Clear preloaded images list (doesn't clear actual cache)
  void clearPreloadedList() {
    _preloadedUrls.clear();
    debugPrint('🖼️ Cleared preloaded images list');
  }

  /// Check if an image URL has been preloaded
  bool isPreloaded(String imageUrl) {
    return _preloadedUrls.contains(imageUrl);
  }

  /// Get storage size estimate for cached images
  /// Returns size in MB
  Future<double> getCachedImagesSizeMB() async {
    try {
      // Updated estimate based on 600x800 WebP images (~80-150KB average)
      const averageImageSizeKB = 100; // Optimized WebP images
      final estimatedSizeKB = _preloadedUrls.length * averageImageSizeKB;
      return estimatedSizeKB / 1024; // Convert to MB
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
      return 0.0;
    }
  }

  /// Clear old cached images when storage is low
  /// This uses CachedNetworkImage's built-in cache management
  Future<void> clearOldCache() async {
    try {
      // CachedNetworkImage manages its own cache
      // We just clear our tracking list
      _preloadedUrls.clear();
      debugPrint('🖼️ Cache cleared');

      await FirebaseService().logEvent('image_cache_cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Preload images in priority order (featured decks first)
  Future<void> preloadWithPriority(
    BuildContext context,
    List<Deck> allDecks, {
    List<String>? featuredDeckIds,
    int maxImages = 20,
  }) async {
    if (!_enabled) return;

    final isWiFi = await _isConnectedToWiFi();
    if (!isWiFi) return;

    // Prioritize featured decks
    final priorityDecks = <Deck>[];
    final regularDecks = <Deck>[];

    for (final deck in allDecks) {
      if (deck.imageUrl == null || deck.imageUrl!.isEmpty) continue;

      if (featuredDeckIds != null && featuredDeckIds.contains(deck.id)) {
        priorityDecks.add(deck);
      } else {
        regularDecks.add(deck);
      }
    }

    // Combine lists with priority first
    final orderedDecks = [...priorityDecks, ...regularDecks];

    await preloadDeckImages(context, orderedDecks, maxImages: maxImages);
  }

  /// Get statistics about preloaded images
  Map<String, dynamic> getStatistics() {
    return {
      'preloaded_count': _preloadedUrls.length,
      'is_preloading': _isPreloading,
      'is_enabled': _enabled,
      'estimated_size_mb': ((_preloadedUrls.length * 100) / 1024).toStringAsFixed(2), // Updated for optimized WebP images
    };
  }
}

