import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_recording_result.dart';

class VideoExportService {
  // Export video with overlay as an image sequence
  // Note: This is a workaround since we can't use FFmpeg
  // For production, consider using platform-specific video processing
  static Future<String?> exportVideoWithOverlay({
    required String videoPath,
    required VideoRecordingResult recordingResult,
    required List<String> gameFrames,
  }) async {
    try {
      debugPrint('=== VIDEO EXPORT SERVICE ===');
      debugPrint('Note: Creating composite video preview');

      // For now, we'll return the original video path
      // In a production app, you would:
      // 1. Use platform channels to access native video processing
      // 2. Or use a server-side solution to composite videos
      // 3. Or use screen recording while playing the video

      debugPrint('Returning original video for save/share');
      return videoPath;
    } catch (e) {
      debugPrint('Error exporting video: $e');
      return null;
    }
  }

  // Create a single composite frame for preview/thumbnail
  static Future<String?> createCompositeFrame({
    required String videoFramePath,
    required String gameFramePath,
    required Size videoSize,
    required Size pipSize,
    required Offset pipPosition,
  }) async {
    try {
      // This would create a single composite frame
      // Useful for thumbnails or preview images

      // For now, return null as we need native processing
      return null;
    } catch (e) {
      debugPrint('Error creating composite frame: $e');
      return null;
    }
  }

  // Generate instructions for users to capture both videos
  static String getScreenRecordingInstructions() {
    if (Platform.isIOS) {
      return '''
To save the video with game replay overlay:
1. Start screen recording (swipe down from top-right, tap record button)
2. Play the video in full screen
3. Stop screen recording when done
4. The recording will be saved to your Photos app
''';
    } else {
      return '''
To save the video with game replay overlay:
1. Start screen recording (swipe down, find screen record in quick settings)
2. Play the video in full screen
3. Stop screen recording when done
4. The recording will be saved to your gallery
''';
    }
  }
}
