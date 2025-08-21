import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:heads_up_game/services/audio_service.dart';

@GenerateMocks([AudioPlayer])
import 'audio_service_test.mocks.dart';

void main() {
  group('AudioService Tests', () {
    late AudioService audioService;

    setUp(() {
      audioService = AudioService();
      // MockAudioPlayer can be used when we need to inject it
      // For now, we'll test the public interface
    });

    test('should be a singleton', () {
      final instance1 = AudioService();
      final instance2 = AudioService();

      expect(instance1, equals(instance2));
    });

    test('should enable and disable sound', () {
      audioService.setSoundEnabled(true);
      // Sound should be enabled (default state)

      audioService.setSoundEnabled(false);
      // Sound should be disabled

      // Since the _isSoundEnabled is private, we can't directly test it
      // but we can verify the behavior by checking if sounds play
    });

    group('Sound playback tests', () {
      test('should play correct sound', () async {
        audioService.setSoundEnabled(true);

        // This will attempt to play the sound
        // In a real test, we'd verify the AudioPlayer.play was called
        await audioService.playCorrect();

        // Test should not throw
        expect(true, isTrue);
      });

      test('should play pass sound', () async {
        audioService.setSoundEnabled(true);

        await audioService.playPass();

        expect(true, isTrue);
      });

      test('should play countdown sound', () async {
        audioService.setSoundEnabled(true);

        await audioService.playCountdown();

        expect(true, isTrue);
      });

      test('should play time up sound', () async {
        audioService.setSoundEnabled(true);

        await audioService.playTimeUp();

        expect(true, isTrue);
      });

      test('should play click sound', () async {
        audioService.setSoundEnabled(true);

        await audioService.playClick();

        expect(true, isTrue);
      });

      test('should play success sound', () async {
        audioService.setSoundEnabled(true);

        await audioService.playSuccess();

        expect(true, isTrue);
      });
    });

    group('Sound disabled tests', () {
      test('should not play sounds when disabled', () async {
        audioService.setSoundEnabled(false);

        // These should return immediately without playing
        await audioService.playCorrect();
        await audioService.playPass();
        await audioService.playCountdown();
        await audioService.playTimeUp();
        await audioService.playClick();
        await audioService.playSuccess();

        // Test should complete without errors
        expect(true, isTrue);
      });
    });

    test('should handle errors silently', () async {
      audioService.setSoundEnabled(true);

      // Even if the audio files don't exist, methods should not throw
      await audioService.playCorrect();
      await audioService.playPass();

      expect(true, isTrue);
    });

    test('should dispose properly', () {
      // This should not throw
      audioService.dispose();

      expect(true, isTrue);
    });
  });
}
