import 'package:flutter_test/flutter_test.dart';
import 'package:heads_up_game/motion/motion_config.dart';
import 'package:heads_up_game/motion/motion_classifier.dart';

void main() {
  group('MotionClassifier', () {
    late MotionClassifier classifier;
    late MotionConfig config;

    setUp(() {
      config = const MotionConfig(
        forwardEnterDeg: -28.0,
        forwardExitDeg: -18.0,
        backEnterDeg: 28.0,
        backExitDeg: 18.0,
        holdMs: 120,
        cooldownMs: 700,
        lpfAlpha: 0.20,
      );
      classifier = MotionClassifier(config: config);

      // Set up calibration
      classifier.setCalibration(const CalibrationData(
        neutralPitchDeg: 0.0,
        orientationSign: 1.0,
        timestamp: DateTime(2025, 1, 1),
      ));
    });

    group('State Transitions', () {
      test('should start in neutral state', () {
        expect(classifier.currentState, equals(MotionState.neutral));
      });

      test('should enter forward pending when tilting forward past threshold',
          () {
        final now = DateTime.now();

        // Simulate forward tilt
        classifier.feed(
          ax: 5.5, // Will result in negative pitch
          ay: 0.0,
          az: 8.5,
          timestamp: now,
        );

        expect(classifier.currentState, equals(MotionState.fwdPending));
      });

      test('should enter back pending when tilting back past threshold', () {
        final now = DateTime.now();

        // Simulate backward tilt
        classifier.feed(
          ax: -5.5, // Will result in positive pitch
          ay: 0.0,
          az: 8.5,
          timestamp: now,
        );

        expect(classifier.currentState, equals(MotionState.backPending));
      });

      test('should return to neutral when exiting forward threshold', () {
        final now = DateTime.now();

        // Enter forward pending
        classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now,
        );
        expect(classifier.currentState, equals(MotionState.fwdPending));

        // Return to neutral zone
        classifier.feed(
          ax: 3.0, // Less tilt
          ay: 0.0,
          az: 9.5,
          timestamp: now.add(const Duration(milliseconds: 50)),
        );

        expect(classifier.currentState, equals(MotionState.neutral));
      });
    });

    group('Gesture Detection', () {
      test('should fire correct gesture after holding forward tilt', () {
        final now = DateTime.now();
        GestureEvent? event;

        // Enter forward pending
        event = classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now,
        );
        expect(event, isNull);
        expect(classifier.currentState, equals(MotionState.fwdPending));

        // Hold for just under threshold
        event = classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now.add(const Duration(milliseconds: 100)),
        );
        expect(event, isNull);
        expect(classifier.currentState, equals(MotionState.fwdPending));

        // Hold past threshold
        event = classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now.add(const Duration(milliseconds: 130)),
        );
        expect(event, isNotNull);
        expect(event!.type, equals(GestureType.correct));
        expect(classifier.currentState, equals(MotionState.cooldown));
      });

      test('should fire pass gesture after holding back tilt', () {
        final now = DateTime.now();
        GestureEvent? event;

        // Enter back pending
        event = classifier.feed(
          ax: -5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now,
        );
        expect(event, isNull);
        expect(classifier.currentState, equals(MotionState.backPending));

        // Hold past threshold
        event = classifier.feed(
          ax: -5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now.add(const Duration(milliseconds: 130)),
        );
        expect(event, isNotNull);
        expect(event!.type, equals(GestureType.pass));
        expect(classifier.currentState, equals(MotionState.cooldown));
      });

      test('should not fire gesture if returning to neutral before hold time',
          () {
        final now = DateTime.now();
        GestureEvent? event;

        // Enter forward pending
        event = classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now,
        );
        expect(classifier.currentState, equals(MotionState.fwdPending));

        // Return to neutral before hold time
        event = classifier.feed(
          ax: 0.0,
          ay: 0.0,
          az: 9.8,
          timestamp: now.add(const Duration(milliseconds: 50)),
        );
        expect(event, isNull);
        expect(classifier.currentState, equals(MotionState.neutral));
      });
    });

    group('Cooldown', () {
      test('should prevent new gestures during cooldown', () {
        final now = DateTime.now();
        GestureEvent? event;

        // Fire a gesture to enter cooldown
        classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now,
        );
        event = classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now.add(const Duration(milliseconds: 130)),
        );
        expect(event!.type, equals(GestureType.correct));
        expect(classifier.currentState, equals(MotionState.cooldown));

        // Try to trigger another gesture during cooldown
        event = classifier.feed(
          ax: -5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now.add(const Duration(milliseconds: 200)),
        );
        expect(event, isNull);
        expect(classifier.currentState, equals(MotionState.cooldown));
      });

      test('should exit cooldown after time elapsed and in neutral band', () {
        final now = DateTime.now();

        // Fire a gesture to enter cooldown
        classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now,
        );
        classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now.add(const Duration(milliseconds: 130)),
        );
        expect(classifier.currentState, equals(MotionState.cooldown));

        // Wait for cooldown but stay tilted
        classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now.add(const Duration(milliseconds: 850)),
        );
        expect(classifier.currentState, equals(MotionState.cooldown));

        // Return to neutral after cooldown elapsed
        classifier.feed(
          ax: 0.0,
          ay: 0.0,
          az: 9.8,
          timestamp: now.add(const Duration(milliseconds: 900)),
        );
        expect(classifier.currentState, equals(MotionState.neutral));
      });
    });

    group('Gyroscope Support', () {
      test('should allow entry without gyro when not required', () {
        final now = DateTime.now();

        classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          gy: 0.0, // No gyro motion
          timestamp: now,
        );

        expect(classifier.currentState, equals(MotionState.fwdPending));
      });

      test('should require gyro motion when configured', () {
        // Create classifier with gyro requirement
        final strictConfig = config.copyWith(requireGyroForEnter: true);
        final strictClassifier = MotionClassifier(config: strictConfig);
        strictClassifier.setCalibration(const CalibrationData(
          neutralPitchDeg: 0.0,
          orientationSign: 1.0,
          timestamp: DateTime(2025, 1, 1),
        ));

        final now = DateTime.now();

        // Try to enter without gyro motion
        strictClassifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          gy: 0.0, // No gyro motion
          timestamp: now,
        );
        expect(strictClassifier.currentState, equals(MotionState.neutral));

        // Enter with sufficient gyro motion
        strictClassifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          gy: -40.0, // Sufficient gyro motion
          timestamp: now.add(const Duration(milliseconds: 50)),
        );
        expect(strictClassifier.currentState, equals(MotionState.fwdPending));
      });
    });

    group('Z-Axis Fallback Mode', () {
      test('should detect gestures using Z-axis thresholds', () {
        // Create classifier with Z-axis mode
        final zConfig = config.copyWith(useZAxisFallback: true);
        final zClassifier = MotionClassifier(config: zConfig);

        final now = DateTime.now();
        GestureEvent? event;

        // Forward gesture with Z-axis
        event = zClassifier.feedZAxis(
          z: -8.0, // Below forward threshold
          timestamp: now,
        );
        expect(zClassifier.currentState, equals(MotionState.fwdPending));

        // Hold for gesture
        event = zClassifier.feedZAxis(
          z: -8.0,
          timestamp: now.add(const Duration(milliseconds: 130)),
        );
        expect(event!.type, equals(GestureType.correct));
      });
    });

    group('Calibration', () {
      test('should handle different orientation signs', () {
        // Set calibration with reversed orientation
        classifier.setCalibration(const CalibrationData(
          neutralPitchDeg: 0.0,
          orientationSign: -1.0, // Reversed
          timestamp: DateTime(2025, 1, 1),
        ));

        final now = DateTime.now();

        // What would normally be forward is now backward
        classifier.feed(
          ax: 5.5,
          ay: 0.0,
          az: 8.5,
          timestamp: now,
        );

        expect(classifier.currentState, equals(MotionState.backPending));
      });

      test('should apply neutral pitch offset', () {
        // Set calibration with offset neutral
        classifier.setCalibration(const CalibrationData(
          neutralPitchDeg: 10.0, // Device starts at 10° pitch
          orientationSign: 1.0,
          timestamp: DateTime(2025, 1, 1),
        ));

        // The relative pitch calculation should account for this offset
        expect(classifier.relativePitch, closeTo(-10.0, 2.0));
      });
    });

    group('Low-Pass Filter', () {
      test('should smooth pitch values', () {
        final now = DateTime.now();

        // Feed sudden change
        classifier.feed(
          ax: 0.0,
          ay: 0.0,
          az: 9.8,
          timestamp: now,
        );
        final pitch1 = classifier.currentPitch;

        // Feed very different value
        classifier.feed(
          ax: 5.0,
          ay: 0.0,
          az: 8.5,
          timestamp: now.add(const Duration(milliseconds: 16)),
        );
        final pitch2 = classifier.currentPitch;

        // The change should be dampened by LPF
        final rawChange = 5.0; // Approximate expected raw change
        final filteredChange = (pitch2 - pitch1).abs();

        expect(filteredChange, lessThan(rawChange));
      });
    });
  });
}
