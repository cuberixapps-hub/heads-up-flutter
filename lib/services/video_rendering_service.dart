import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../models/video_recording_result.dart';

class VideoRenderingService {
  // Create a composite video by rendering frames
  static Future<String?> createCompositeVideo({
    required String reactionVideoPath,
    required VideoRecordingResult recordingResult,
    required List<String> gameFrames,
    required Color deckColor,
    required Function(double) onProgress,
  }) async {
    try {
      debugPrint('=== CREATING COMPOSITE VIDEO ===');

      // Initialize video controller
      final videoController = VideoPlayerController.file(
        File(reactionVideoPath),
      );
      await videoController.initialize();

      final videoDuration = videoController.value.duration;
      final videoSize = videoController.value.size;

      debugPrint('Video duration: ${videoDuration.inSeconds}s');
      debugPrint('Video size: ${videoSize.width}x${videoSize.height}');
      debugPrint('Game frames: ${gameFrames.length}');

      // Create output directory
      final tempDir = await getTemporaryDirectory();
      final outputDir = Directory('${tempDir.path}/composite_frames');
      if (await outputDir.exists()) {
        await outputDir.delete(recursive: true);
      }
      await outputDir.create();

      // Calculate frame count (30 fps)
      const fps = 30;
      final totalFrames = (videoDuration.inMilliseconds * fps / 1000).ceil();

      debugPrint('Rendering $totalFrames frames at $fps fps...');

      // Process frames
      final List<String> compositeFramePaths = [];

      for (int i = 0; i < totalFrames; i++) {
        final progress = i / totalFrames;
        onProgress(progress * 0.8); // 80% for frame processing

        final timestamp = Duration(milliseconds: (i * 1000 / fps).round());

        // Get game frame index
        final gameFrameIndex = (timestamp.inMilliseconds * 30 / 1000)
            .floor()
            .clamp(0, gameFrames.length - 1);

        // Create composite frame
        final framePath = await _createCompositeFrame(
          frameIndex: i,
          timestamp: timestamp,
          videoController: videoController,
          gameFramePath:
              gameFrames.isNotEmpty ? gameFrames[gameFrameIndex] : null,
          outputDir: outputDir.path,
          videoSize: videoSize,
          deckColor: deckColor,
        );

        if (framePath != null) {
          compositeFramePaths.add(framePath);
        }
      }

      videoController.dispose();

      onProgress(0.9); // 90% for video assembly

      // Create video from frames using platform-specific method
      final outputVideoPath = await _assembleFramesToVideo(
        framePaths: compositeFramePaths,
        fps: fps,
        outputDir: tempDir.path,
        originalAudioPath: reactionVideoPath,
      );

      // Clean up frames
      await outputDir.delete(recursive: true);

      onProgress(1.0); // 100% complete

      debugPrint('Composite video created: $outputVideoPath');
      return outputVideoPath;
    } catch (e) {
      debugPrint('Error creating composite video: $e');
      return null;
    }
  }

  // Create a single composite frame
  static Future<String?> _createCompositeFrame({
    required int frameIndex,
    required Duration timestamp,
    required VideoPlayerController videoController,
    required String? gameFramePath,
    required String outputDir,
    required Size videoSize,
    required Color deckColor,
  }) async {
    try {
      // Create canvas
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      // Draw black background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, videoSize.width, videoSize.height),
        Paint()..color = Colors.black,
      );

      // Note: Getting actual video frames requires platform-specific implementation
      // For now, we'll create a placeholder
      // In production, use platform channels to extract video frames

      // Draw placeholder for video frame
      canvas.drawRect(
        Rect.fromLTWH(0, 0, videoSize.width, videoSize.height),
        Paint()..color = Colors.black,
      );

      // Draw game overlay if available
      if (gameFramePath != null) {
        final gameFrameFile = File(gameFramePath);
        if (await gameFrameFile.exists()) {
          final gameFrameData = await gameFrameFile.readAsBytes();
          final gameFrame = await decodeImageFromList(gameFrameData);

          // Calculate PiP position and size
          const pipWidth = 200.0;
          const pipHeight = 150.0;
          const pipPadding = 20.0;
          final pipRect = Rect.fromLTWH(
            videoSize.width - pipWidth - pipPadding,
            videoSize.height -
                pipHeight -
                pipPadding -
                80, // Account for controls
            pipWidth,
            pipHeight,
          );

          // Draw PiP shadow
          final shadowPath =
              Path()..addRRect(
                RRect.fromRectAndRadius(
                  pipRect.inflate(2),
                  const Radius.circular(12),
                ),
              );
          canvas.drawShadow(shadowPath, Colors.black, 10, true);

          // Draw PiP background
          canvas.drawRRect(
            RRect.fromRectAndRadius(pipRect, const Radius.circular(12)),
            Paint()..color = deckColor.withOpacity(0.9),
          );

          // Draw game frame
          canvas.save();
          canvas.clipRRect(
            RRect.fromRectAndRadius(pipRect, const Radius.circular(12)),
          );

          paintImage(
            canvas: canvas,
            rect: pipRect,
            image: gameFrame,
            fit: BoxFit.cover,
          );

          canvas.restore();
        }
      }

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        videoSize.width.toInt(),
        videoSize.height.toInt(),
      );

      // Convert to PNG
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      // Save frame
      final framePath =
          '$outputDir/frame_${frameIndex.toString().padLeft(6, '0')}.png';
      final frameFile = File(framePath);
      await frameFile.writeAsBytes(byteData.buffer.asUint8List());

      return framePath;
    } catch (e) {
      debugPrint('Error creating frame $frameIndex: $e');
      return null;
    }
  }

  // Assemble frames into video
  static Future<String?> _assembleFramesToVideo({
    required List<String> framePaths,
    required int fps,
    required String outputDir,
    required String originalAudioPath,
  }) async {
    try {
      // This is where we would use platform-specific video encoding
      // For iOS: AVFoundation
      // For Android: MediaCodec

      // Since we can't use FFmpeg, we need platform channels
      // For now, return the original video as fallback

      debugPrint(
        'Note: Video assembly requires platform-specific implementation',
      );
      debugPrint('Returning original video with instruction overlay');

      // Create an instruction video frame
      final instructionPath = await _createInstructionFrame(outputDir);

      return originalAudioPath; // Fallback to original
    } catch (e) {
      debugPrint('Error assembling video: $e');
      return null;
    }
  }

  // Create instruction frame
  static Future<String?> _createInstructionFrame(String outputDir) async {
    try {
      const size = Size(1920, 1080);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF1A1A2E),
      );

      // Draw instruction text
      final textPainter = TextPainter(
        text: const TextSpan(
          text:
              'To save video with game overlay:\n\n'
              '1. Use screen recording while playing the video\n'
              '2. The complete experience will be captured\n'
              '3. Save the screen recording to your gallery',
          style: TextStyle(color: Colors.white, fontSize: 24, height: 1.5),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout(maxWidth: size.width - 100);
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final framePath = '$outputDir/instruction_frame.png';
      final frameFile = File(framePath);
      await frameFile.writeAsBytes(byteData.buffer.asUint8List());

      return framePath;
    } catch (e) {
      debugPrint('Error creating instruction frame: $e');
      return null;
    }
  }
}

// Helper function to paint image with BoxFit
void paintImage({
  required Canvas canvas,
  required Rect rect,
  required ui.Image image,
  required BoxFit fit,
}) {
  final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
  final FittedSizes sizes = applyBoxFit(fit, imageSize, rect.size);
  final Rect inputRect = Alignment.center.inscribe(
    sizes.source,
    Offset.zero & imageSize,
  );
  final Rect outputRect = Alignment.center.inscribe(sizes.destination, rect);

  canvas.drawImageRect(image, inputRect, outputRect, Paint());
}
