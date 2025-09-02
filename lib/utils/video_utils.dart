import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class VideoUtils {
  // Save video to device gallery
  static Future<bool> saveVideoToGallery(String videoPath) async {
    try {
      // Get the source file
      final sourceFile = File(videoPath);
      if (!await sourceFile.exists()) {
        debugPrint('Source video file not found');
        return false;
      }

      // On iOS, we can save directly to Photos
      // On Android, we save to a accessible directory
      if (Platform.isIOS) {
        // For iOS, we can copy to Documents directory which user can access via Files app
        final documentsDir = await getApplicationDocumentsDirectory();
        final headsUpDir = Directory('${documentsDir.path}/HeadsUp');
        if (!await headsUpDir.exists()) {
          await headsUpDir.create(recursive: true);
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'HeadsUp_Reaction_$timestamp.mp4';
        final destinationPath = '${headsUpDir.path}/$filename';

        await sourceFile.copy(destinationPath);
        debugPrint('Video saved to: $destinationPath');
        return true;
      } else {
        // For Android, save to external storage
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          debugPrint('Could not access external storage');
          return false;
        }

        // Create HeadsUp directory in Movies
        final headsUpDir = Directory('${directory.path}/Movies/HeadsUp');
        if (!await headsUpDir.exists()) {
          await headsUpDir.create(recursive: true);
        }

        // Generate filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'HeadsUp_Reaction_$timestamp.mp4';
        final destinationPath = '${headsUpDir.path}/$filename';

        // Copy file
        await sourceFile.copy(destinationPath);

        debugPrint('Video saved to gallery: $destinationPath');
        return true;
      }
    } catch (e) {
      debugPrint('Error saving video to gallery: $e');
      return false;
    }
  }

  // Share video with caption
  static Future<void> shareVideo({
    required String videoPath,
    required String deckName,
    required int score,
    required int correctCount,
    required int passCount,
  }) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        debugPrint('Video file not found for sharing');
        return;
      }

      // Create share message
      final message = '''
🎮 Check out my Heads Up! reaction video!

📚 Category: $deckName
🏆 Score: ${score * 10} points
✅ Correct: $correctCount
⏭️ Passed: $passCount

Had so much fun playing! Download Heads Up! and challenge me!
#HeadsUp #GameNight #ReactionVideo
''';

      // Share video with message
      await Share.shareXFiles(
        [XFile(videoPath)],
        text: message,
        subject: 'My Heads Up! Reaction Video',
      );

      debugPrint('Video shared successfully');
    } catch (e) {
      debugPrint('Error sharing video: $e');
    }
  }

  // Delete temporary video file
  static Future<bool> deleteTemporaryVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Temporary video deleted: $videoPath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting video: $e');
      return false;
    }
  }

  // Get video file size in MB
  static Future<double> getVideoSizeMB(String videoPath) async {
    try {
      final file = File(videoPath);
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024);
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting video size: $e');
      return 0;
    }
  }

  // Check if device has enough storage space (at least 100MB)
  static Future<bool> hasEnoughStorage() async {
    try {
      final tempDir = await getTemporaryDirectory();

      // Get available space using statfs on the temp directory
      final stat = await Process.run('df', [tempDir.path]);
      if (stat.exitCode == 0) {
        final output = stat.stdout as String;
        final lines = output.split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length > 3) {
            final availableKB = int.tryParse(parts[3]) ?? 0;
            final availableMB = availableKB / 1024;
            return availableMB > 100; // Need at least 100MB
          }
        }
      }

      // Default to true if we can't determine
      return true;
    } catch (e) {
      debugPrint('Error checking storage: $e');
      return true; // Assume we have space if check fails
    }
  }
}
