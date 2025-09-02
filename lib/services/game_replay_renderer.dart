import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

import 'dart:typed_data';

import '../models/video_recording_result.dart';

class GameReplayRenderer {
  static const double frameWidth = 400;
  static const double frameHeight = 300;
  static const int fps = 30;

  // Generate game replay video
  // Note: Video generation requires FFmpeg or native platform implementation
  // For now, this feature is disabled due to FFmpeg compatibility issues
  static Future<String?> generateGameReplay({
    required VideoRecordingResult recordingResult,
    required Color deckColor,
    required Duration gameDuration,
  }) async {
    try {
      debugPrint('Game replay generation requested...');
      debugPrint('Note: Game replay overlay is currently disabled');

      // The frame generation code is preserved for future use
      // when FFmpeg or an alternative solution is implemented

      // For now, return null to indicate no game replay video
      // The main reaction video will still be available
      return null;
    } catch (e) {
      debugPrint('Error in game replay generation: $e');
      return null;
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
      // Get current event at this timestamp
      final currentEvent = recordingResult.getEventAtTime(timestamp);
      if (currentEvent == null) return null;

      // Create picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(frameWidth, frameHeight);

      // Draw background with rounded corners
      final bgPaint = Paint()..color = deckColor.withOpacity(0.95);
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(20),
      );
      canvas.drawRRect(bgRect, bgPaint);

      // Add subtle gradient overlay
      final gradientPaint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withOpacity(0.1), Colors.transparent],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height / 2));
      canvas.drawRRect(bgRect, gradientPaint);

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
                remainingTime.inSeconds <= 10 ? Colors.redAccent : Colors.white,
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
            style: TextStyle(
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
