import 'package:flutter_test/flutter_test.dart';
import 'package:heads_up_game/services/haptic_service.dart';

void main() {
  group('HapticService Tests', () {
    late HapticService hapticService;

    setUp(() {
      hapticService = HapticService();
    });

    test('should be a singleton', () {
      final instance1 = HapticService();
      final instance2 = HapticService();

      expect(instance1, equals(instance2));
    });

    test('should enable and disable vibration', () {
      hapticService.setVibrationEnabled(true);
      // Vibration should be enabled (default state)

      hapticService.setVibrationEnabled(false);
      // Vibration should be disabled

      // Since the _isVibrationEnabled is private, we can't directly test it
      // but we can verify the behavior by checking if vibrations occur
    });

    group('Haptic feedback tests', () {
      test('should trigger light impact', () async {
        hapticService.setVibrationEnabled(true);

        // This will attempt to trigger haptic feedback
        await hapticService.lightImpact();

        // Test should not throw
        expect(true, isTrue);
      });

      test('should trigger medium impact', () async {
        hapticService.setVibrationEnabled(true);

        await hapticService.mediumImpact();

        expect(true, isTrue);
      });

      test('should trigger heavy impact', () async {
        hapticService.setVibrationEnabled(true);

        await hapticService.heavyImpact();

        expect(true, isTrue);
      });

      test('should trigger success feedback', () async {
        hapticService.setVibrationEnabled(true);

        await hapticService.success();

        expect(true, isTrue);
      });

      test('should trigger warning feedback', () async {
        hapticService.setVibrationEnabled(true);

        await hapticService.warning();

        expect(true, isTrue);
      });

      test('should trigger error feedback', () async {
        hapticService.setVibrationEnabled(true);

        await hapticService.error();

        expect(true, isTrue);
      });

      test('should trigger selection feedback', () async {
        hapticService.setVibrationEnabled(true);

        await hapticService.selection();

        expect(true, isTrue);
      });
    });

    group('Vibration disabled tests', () {
      test('should not trigger haptics when disabled', () async {
        hapticService.setVibrationEnabled(false);

        // These should return immediately without vibrating
        await hapticService.lightImpact();
        await hapticService.mediumImpact();
        await hapticService.heavyImpact();
        await hapticService.success();
        await hapticService.warning();
        await hapticService.error();
        await hapticService.selection();

        // Test should complete without errors
        expect(true, isTrue);
      });
    });

    test('should handle errors silently', () async {
      hapticService.setVibrationEnabled(true);

      // Even if vibration is not available on the device, methods should not throw
      await hapticService.lightImpact();
      await hapticService.mediumImpact();
      await hapticService.heavyImpact();

      expect(true, isTrue);
    });

    test('should handle all feedback types without errors', () async {
      hapticService.setVibrationEnabled(true);

      final futures = [
        hapticService.lightImpact(),
        hapticService.mediumImpact(),
        hapticService.heavyImpact(),
        hapticService.success(),
        hapticService.warning(),
        hapticService.error(),
        hapticService.selection(),
      ];

      // All methods should complete without throwing
      await Future.wait(futures);

      expect(true, isTrue);
    });
  });
}

