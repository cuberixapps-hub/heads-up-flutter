import 'dart:io';
import 'package:flutter/material.dart';

class VideoOverlayFrameManager {
  final List<String> framePaths;
  final BuildContext context;
  final Map<int, Image> _cachedImages = {};
  bool _isPreloading = false;

  VideoOverlayFrameManager({required this.framePaths, required this.context});

  // Preload frames around the current index for smooth playback
  Future<void> preloadFrames(int currentIndex, {int radius = 10}) async {
    if (_isPreloading || framePaths.isEmpty) return;
    _isPreloading = true;

    try {
      final start = (currentIndex - radius).clamp(0, framePaths.length - 1);
      final end = (currentIndex + radius).clamp(0, framePaths.length - 1);

      final futures = <Future>[];

      for (int i = start; i <= end; i++) {
        if (!_cachedImages.containsKey(i)) {
          futures.add(_loadFrame(i));
        }
      }

      // Clean up old frames outside the window
      _cachedImages.removeWhere(
        (index, _) => index < start - radius || index > end + radius,
      );

      await Future.wait(futures);
    } finally {
      _isPreloading = false;
    }
  }

  Future<void> _loadFrame(int index) async {
    if (index < 0 || index >= framePaths.length) return;

    try {
      final image = Image.file(
        File(framePaths[index]),
        fit: BoxFit.cover,
        cacheWidth: 400, // Match frame dimensions
        cacheHeight: 300,
      );

      // Precache the image
      await precacheImage(image.image, context);
      _cachedImages[index] = image;
    } catch (e) {
      debugPrint('Error loading frame $index: $e');
    }
  }

  Widget? getFrame(int index) {
    return _cachedImages[index];
  }

  void dispose() {
    _cachedImages.clear();
  }
}
