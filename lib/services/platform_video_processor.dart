import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_recording_result.dart';

class PlatformVideoProcessor {
  static const platform = MethodChannel('com.headsup.video_processor');

  /// Process and composite video with game overlay
  /// Returns the path to the processed video
  static Future<String?> processVideoWithOverlay({
    required String reactionVideoPath,
    required VideoRecordingResult recordingResult,
    required List<String> gameFramePaths,
    required Function(double) onProgress,
  }) async {
    try {
      // For web/desktop, we'll use a simpler approach
      if (!Platform.isIOS && !Platform.isAndroid) {
        return null;
      }

      // Create temporary output path
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/composite_$timestamp.mp4';

      // Call platform-specific implementation
      final result = await platform.invokeMethod<String>('processVideo', {
        'reactionVideoPath': reactionVideoPath,
        'gameFramePaths': gameFramePaths,
        'outputPath': outputPath,
        'pipWidth': 200,
        'pipHeight': 150,
        'pipX': 20, // From right
        'pipY': 100, // From bottom
      });

      return result;
    } catch (e) {
      debugPrint('Platform video processing not available: $e');
      return null;
    }
  }
}
