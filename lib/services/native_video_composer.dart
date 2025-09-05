import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_recording_result.dart';

class NativeVideoComposer {
  static const platform = MethodChannel('com.headsup.video_composer');

  /// Compose video with overlay using native platform code
  static Future<String?> composeVideoWithOverlay({
    required String reactionVideoPath,
    required VideoRecordingResult recordingResult,
    required List<String> gameFrames,
    required Color deckColor,
    required Function(double) onProgress,
  }) async {
    try {
      debugPrint('=== NATIVE VIDEO COMPOSITION ===');
      debugPrint('Reaction video: $reactionVideoPath');
      debugPrint('Game frames count: ${gameFrames.length}');

      // Verify all frame files exist
      for (int i = 0; i < gameFrames.length && i < 5; i++) {
        final frameFile = File(gameFrames[i]);
        debugPrint(
          'Frame $i: ${gameFrames[i]} - exists: ${frameFile.existsSync()}',
        );
        if (frameFile.existsSync()) {
          debugPrint('Frame $i size: ${frameFile.lengthSync()} bytes');
        }
      }

      // Create temporary directory for output
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/composite_$timestamp.mp4';

      // Prepare parameters for native code
      final Map<String, dynamic> params = {
        'reactionVideoPath': reactionVideoPath,
        'gameFramePaths': gameFrames,
        'outputPath': outputPath,
        'pipWidth': 200,
        'pipHeight': 150,
        'pipX': 20, // From right
        'pipY': 100, // From bottom
        'fps': 30,
        'duration': recordingResult.duration.inMilliseconds,
        'deckColorHex': '#${deckColor.value.toRadixString(16).padLeft(8, '0')}',
      };

      // Set up progress listener
      const EventChannel progressChannel = EventChannel(
        'com.headsup.video_composer/progress',
      );
      final progressSubscription = progressChannel
          .receiveBroadcastStream()
          .listen((dynamic progress) {
            if (progress is double) {
              onProgress(progress);
            }
          });

      try {
        // Call native method
        final String? result = await platform.invokeMethod(
          'composeVideo',
          params,
        );

        if (result != null && File(result).existsSync()) {
          debugPrint('Native video composition successful: $result');
          return result;
        } else {
          debugPrint('Native video composition failed');
          return null;
        }
      } finally {
        // Clean up progress listener
        await progressSubscription.cancel();
      }
    } on PlatformException catch (e) {
      debugPrint('Platform error in video composition: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error in native video composition: $e');
      return null;
    }
  }

  /// Alternative: Create instructions for users
  static Future<bool> showCompositionInstructions(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Save Complete Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 48,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'To save the video with game overlay:',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStep('1', 'Use screen recording'),
                          const SizedBox(height: 8),
                          _buildStep('2', 'Play the video in the app'),
                          const SizedBox(height: 8),
                          _buildStep('3', 'Stop recording when done'),
                          const SizedBox(height: 8),
                          _buildStep(
                            '4',
                            'The recording will have both videos!',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      Platform.isIOS
                          ? 'Swipe down from top-right to access screen recording'
                          : 'Pull down quick settings to find screen record',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: const Text('Got it'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  static Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
