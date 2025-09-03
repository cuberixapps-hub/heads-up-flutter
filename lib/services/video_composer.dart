import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/video_recording_result.dart';
import '../services/game_replay_renderer.dart';

class VideoComposer {
  // Note: Video composition with embedded PiP requires FFmpeg which is discontinued
  // We're using dynamic overlay during playback instead
  // This method returns the original video and is kept for compatibility
  static Future<String?> composeVideos({
    required String mainVideoPath,
    required VideoRecordingResult recordingResult,
    required Color deckColor,
  }) async {
    try {
      debugPrint('=== VIDEO COMPOSITION ===');
      debugPrint(
        'Note: Using dynamic overlay approach instead of FFmpeg composition',
      );
      debugPrint('Main video: $mainVideoPath');

      // Verify main video exists
      final mainFile = File(mainVideoPath);
      if (!await mainFile.exists()) {
        debugPrint('Main video file not found');
        return null;
      }

      // Return the original video
      // The PiP overlay is rendered dynamically during playback
      return mainVideoPath;
    } catch (e) {
      debugPrint('Error in video composition: $e');
      return null;
    }
  }

  // Generate video thumbnail
  static Future<String?> generateThumbnail(String videoPath) async {
    try {
      // Thumbnail generation requires FFmpeg or native implementation
      // For now, returning null (video preview will show placeholder)
      debugPrint('Thumbnail generation currently disabled (requires FFmpeg)');
      return null;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }
}
