import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for Heads Up game images
/// Optimized for 600x800 WebP images with extended cache duration
class CustomImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'headsUpImageCache';

  static CustomImageCacheManager? _instance;

  factory CustomImageCacheManager() {
    _instance ??= CustomImageCacheManager._();
    return _instance!;
  }

  CustomImageCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 30), // Keep images for 30 days
          maxNrOfCacheObjects: 300, // Cache up to 300 images (~30MB total)
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ));
}




