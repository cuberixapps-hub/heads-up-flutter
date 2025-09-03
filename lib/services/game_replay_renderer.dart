import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/video_recording_result.dart';

class GameReplayRenderer {
  static const double frameWidth = 400;
  static const double frameHeight = 300;
  static const int fps = 30;

  // Generate game replay video frames as images
  static Future<List<String>> generateGameReplayFrames({
    required VideoRecordingResult recordingResult,
    required Color deckColor,
    required Duration gameDuration,
  }) async {
    try {
      debugPrint('=== GENERATING GAME REPLAY FRAMES ===');
      debugPrint('Total events: ${recordingResult.events.length}');
      debugPrint('Deck name: ${recordingResult.deckName}');
      debugPrint('Game duration: ${gameDuration.inSeconds}s');
      
      // Debug all events
      debugPrint('All events in recording:');
      for (var event in recordingResult.events) {
        debugPrint('  ${event.type}: "${event.word}" at ${event.timestamp.inSeconds}s');
      }

      final frames = <String>[];
      final tempDir = await getTemporaryDirectory();
      final frameDir = Directory('${tempDir.path}/game_frames');

      // Clean up old frames
      if (await frameDir.exists()) {
        await frameDir.delete(recursive: true);
      }
      await frameDir.create();

      // Generate frames at 30 FPS for smooth playback
      const frameRate = 30;
      final totalFrames =
          (gameDuration.inMilliseconds / (1000 / frameRate)).ceil();

      for (int i = 0; i < totalFrames; i++) {
        final timestamp = Duration(
          milliseconds: (i * 1000 / frameRate).round(),
        );

        // Generate frame
        final frameData = await _generateFrame(
          recordingResult: recordingResult,
          timestamp: timestamp,
          deckColor: deckColor,
          gameDuration: gameDuration,
        );

        if (frameData != null) {
          // Save frame as image
          final framePath =
              '${frameDir.path}/frame_${i.toString().padLeft(6, '0')}.png';
          final file = File(framePath);
          await file.writeAsBytes(frameData);
          frames.add(framePath);
        }

        // Show progress
        if (i % 10 == 0) {
          debugPrint('Generated ${i + 1}/$totalFrames frames');
        }
      }

      debugPrint('Game replay frames generated: ${frames.length} frames');
      return frames;
    } catch (e) {
      debugPrint('Error generating game replay frames: $e');
      return [];
    }
  }

  // Generate a single frame
  static Future<Uint8List?> _generateFrame({
    required VideoRecordingResult recordingResult,
    required Duration timestamp,
    required Color deckColor,
    required Duration gameDuration,
  }) async {
    try {
      // Create picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(frameWidth, frameHeight);

      // Background
      final bgPaint = Paint()..color = deckColor.withOpacity(0.9);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // Add subtle gradient overlay
      final gradient = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
        Colors.white.withOpacity(0.1),
        Colors.black.withOpacity(0.2),
      ]);
      final gradientPaint = Paint()..shader = gradient;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        gradientPaint,
      );

      // Get current event at this timestamp
      final currentEvent = recordingResult.getEventAtTime(timestamp);

      if (currentEvent == null || currentEvent.type == 'game_start') {
        // Show "Get Ready!" message if no event yet
        final textPainter = TextPainter(
          text: const TextSpan(
            text: 'Get Ready!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            (size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2,
          ),
        );
      } else {
        // Draw current word (center)
        if (currentEvent.word.isNotEmpty && currentEvent.type != 'game_end') {
          final wordPainter = TextPainter(
            text: TextSpan(
              text: currentEvent.word,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          );
          wordPainter.layout(maxWidth: size.width - 40);
          wordPainter.paint(
            canvas,
            Offset(
              (size.width - wordPainter.width) / 2,
              (size.height - wordPainter.height) / 2,
            ),
          );
        }

        // Draw timer (top-left)
        final remainingTime =
            currentEvent.remainingTime ?? (gameDuration - timestamp);
        final timerText = '${remainingTime.inSeconds}s';
        final timerPainter = TextPainter(
          text: TextSpan(
            text: timerText,
            style: TextStyle(
              color:
                  remainingTime.inSeconds <= 10
                      ? Colors.redAccent
                      : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        timerPainter.layout();

        // Timer background
        final timerBg = Paint()..color = Colors.black.withOpacity(0.3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(15, 15, timerPainter.width + 20, 40),
            const Radius.circular(10),
          ),
          timerBg,
        );
        timerPainter.paint(canvas, const Offset(25, 20));

        // Draw score (top-right)
        final scorePainter = TextPainter(
          text: TextSpan(
            text: 'Score: ${currentEvent.score}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        scorePainter.layout();

        // Score background
        final scoreBg = Paint()..color = Colors.black.withOpacity(0.3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width - scorePainter.width - 35,
              15,
              scorePainter.width + 20,
              40,
            ),
            const Radius.circular(10),
          ),
          scoreBg,
        );
        scorePainter.paint(
          canvas,
          Offset(size.width - scorePainter.width - 25, 20),
        );

        // Draw event indicator (bottom)
        if (currentEvent.type == 'correct' || currentEvent.type == 'pass') {
          final indicatorColor =
              currentEvent.type == 'correct' ? Colors.green : Colors.orange;
          final indicatorText =
              currentEvent.type == 'correct' ? 'CORRECT!' : 'PASS';

          final indicatorPainter = TextPainter(
            text: TextSpan(
              text: indicatorText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          indicatorPainter.layout();

          // Indicator background
          final indicatorBg = Paint()..color = indicatorColor;
          final indicatorRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              (size.width - indicatorPainter.width - 30) / 2,
              size.height - 50,
              indicatorPainter.width + 30,
              35,
            ),
            const Radius.circular(20),
          );
          canvas.drawRRect(indicatorRect, indicatorBg);

          indicatorPainter.paint(
            canvas,
            Offset((size.width - indicatorPainter.width) / 2, size.height - 43),
          );
        }
      }

      // Convert canvas to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        frameWidth.toInt(),
        frameHeight.toInt(),
      );

      // Convert to PNG bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error generating frame: $e');
      return null;
    }
  }
}
