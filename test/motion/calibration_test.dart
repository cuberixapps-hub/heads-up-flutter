import 'package:flutter_test/flutter_test.dart';
import 'package:heads_up_game/motion/motion_config.dart';
import 'package:heads_up_game/motion/motion_classifier.dart';

void main() {
  group('Calibration Tests', () {
    late MotionClassifier classifier;

    setUp(() {
      final config = const MotionConfig();
      classifier = MotionClassifier(config: config);
    });

    group('Landscape Orientation Detection', () {
      test('should detect landscape-left orientation', () {
        // In landscape-left, gravity is mainly on positive Y axis
        // Simulate calibration with landscape-left data
        classifier.setCalibration(const CalibrationData(
          neutralPitchDeg: 5.0,
          orientationSign: 1.0,
          timestamp: DateTime(2025, 1, 1),
        ));

        // Feed data that would be forward tilt in landscape-left
        final event = classifier.feed(
          ax: 5.0, // Forward tilt
          ay: 8.0, // Gravity on Y (landscape)
          az: 2.0,
          timestamp: DateTime.now(),
        );

        // Should detect forward motion
        expect(classifier.currentState, equals(MotionState.fwdPending));
      });

      test('should detect landscape-right orientation', () {
        // In landscape-right, gravity is mainly on negative Y axis
        // Simulate calibration with landscape-right data
        classifier.setCalibration(const CalibrationData(
          neutralPitchDeg: 5.0,
          orientationSign: -1.0, // Reversed for landscape-right
          timestamp: DateTime(2025, 1, 1),
        ));

        // Feed data that would be forward tilt in landscape-right
        final event = classifier.feed(
          ax: 5.0, // This gets reversed by orientationSign
          ay: -8.0, // Gravity on negative Y (landscape-right)
          az: 2.0,
          timestamp: DateTime.now(),
        );

        // Should detect forward motion (after orientation correction)
        expect(classifier.currentState, equals(MotionState.fwdPending));
      });
    });

    group('Neutral Position Calibration', () {
      test('should handle device held at various starting angles', () {
        final testCases = [
          {'neutral': 0.0, 'desc': 'flat'},
          {'neutral': 15.0, 'desc': 'tilted forward'},
          {'neutral': -15.0, 'desc': 'tilted back'},
          {'neutral': 30.0, 'desc': 'significantly tilted'},
        ];

        for (final testCase in testCases) {
          final neutral = testCase['neutral'] as double;
          final desc = testCase['desc'] as String;

          // Reset classifier
          classifier = MotionClassifier(config: const MotionConfig());

          // Set calibration with different neutral positions
          classifier.setCalibration(CalibrationData(
            neutralPitchDeg: neutral,
            orientationSign: 1.0,
            timestamp: DateTime.now(),
          ));

          // Feed data at the neutral position
          classifier.feed(
            ax: -neutral * 0.17, // Approximate conversion
            ay: 0.0,
            az: 9.8,
            timestamp: DateTime.now(),
          );

          // Should be in neutral state regardless of starting angle
          expect(
            classifier.currentState,
            equals(MotionState.neutral),
            reason: 'Failed for device $desc',
          );

          // Relative pitch should be near zero
          expect(
            classifier.relativePitch,
            closeTo(0.0, 5.0),
            reason: 'Relative pitch not normalized for device $desc',
          );
        }
      });
    });

    group('Calibration Stability', () {
      test('should produce consistent results with similar input', () {
        final calibrations = <CalibrationData>[];

        // Simulate multiple calibrations with similar data
        for (int i = 0; i < 5; i++) {
          calibrations.add(CalibrationData(
            neutralPitchDeg: 10.0 + (i * 0.1), // Small variations
            orientationSign: 1.0,
            timestamp: DateTime.now(),
          ));
        }

        // All calibrations should produce similar behavior
        for (final cal in calibrations) {
          classifier.setCalibration(cal);

          // Test forward detection
          classifier.feed(
            ax: 5.5,
            ay: 0.0,
            az: 8.5,
            timestamp: DateTime.now(),
          );

          expect(classifier.currentState, equals(MotionState.fwdPending));
          classifier.reset();
        }
      });
    });

    group('Edge Cases', () {
      test('should handle operation without calibration', () {
        // Create new classifier without calibration
        final uncalibrated = MotionClassifier(config: const MotionConfig());

        // Try to feed data
        final event = uncalibrated.feed(
          ax: 5.0,
          ay: 0.0,
          az: 8.5,
          timestamp: DateTime.now(),
        );

        // Should return null and stay in neutral
        expect(event, isNull);
        expect(uncalibrated.currentState, equals(MotionState.neutral));
      });

      test('should handle extreme calibration values', () {
        // Test with extreme neutral pitch
        classifier.setCalibration(const CalibrationData(
          neutralPitchDeg: 85.0, // Nearly vertical
          orientationSign: 1.0,
          timestamp: DateTime(2025, 1, 1),
        ));

        // Should still function (though not practical)
        classifier.feed(
          ax: 9.0,
          ay: 0.0,
          az: 1.0,
          timestamp: DateTime.now(),
        );

        // State machine should still work
        expect(
          classifier.currentState,
          anyOf([
            equals(MotionState.neutral),
            equals(MotionState.fwdPending),
            equals(MotionState.backPending),
          ]),
        );
      });
    });

    group('Calibration with Real-World Scenarios', () {
      test('should handle shaky calibration data', () {
        // Simulate noisy/shaky calibration
        final times = List.generate(
            30, (i) => DateTime.now().add(Duration(milliseconds: i * 16)));

        // Feed varying data during calibration period
        for (int i = 0; i < times.length; i++) {
          final noise = (i % 2 == 0) ? 0.5 : -0.5;
          classifier.feed(
            ax: 1.0 + noise,
            ay: 0.0 + noise * 0.3,
            az: 9.8 + noise * 0.2,
            timestamp: times[i],
          );
        }

        // Set calibration based on average
        classifier.setCalibration(const CalibrationData(
          neutralPitchDeg: -5.8, // Approximate average from noisy data
          orientationSign: 1.0,
          timestamp: DateTime(2025, 1, 1),
        ));

        // Should still detect gestures properly
        classifier.reset();
        classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: DateTime.now(),
        );

        expect(classifier.currentState, equals(MotionState.fwdPending));
      });

      test('should handle calibration during device movement', () {
        // User might be moving device during calibration
        // This tests if the system can still work with imperfect calibration

        classifier.setCalibration(const CalibrationData(
          neutralPitchDeg: 15.0, // Calibrated while moving
          orientationSign: 1.0,
          timestamp: DateTime(2025, 1, 1),
        ));

        // Even with imperfect calibration, large movements should be detected
        classifier.feed(
          ax: 7.0, // Strong forward tilt
          ay: 0.0,
          az: 7.0,
          timestamp: DateTime.now(),
        );

        // Should still detect the gesture
        expect(classifier.currentState, equals(MotionState.fwdPending));
      });
    });
  });
}
