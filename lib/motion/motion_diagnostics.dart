import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'heads_up_motion_controller.dart';
import 'motion_classifier.dart';

/// Debug overlay widget for motion detection diagnostics
///
/// This widget displays real-time sensor data and motion detection state.
/// It should only be used in debug builds for testing and tuning.
class MotionDiagnosticsOverlay extends StatefulWidget {
  final HeadsUpMotionController controller;
  final bool showRawSensors;

  const MotionDiagnosticsOverlay({
    Key? key,
    required this.controller,
    this.showRawSensors = true,
  }) : super(key: key);

  @override
  State<MotionDiagnosticsOverlay> createState() =>
      _MotionDiagnosticsOverlayState();
}

class _MotionDiagnosticsOverlayState extends State<MotionDiagnosticsOverlay> {
  Timer? _updateTimer;
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;

  // Sensor values
  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;

  // Computed values
  double _pitch = 0;
  double _relativePitch = 0;
  MotionState _state = MotionState.neutral;

  // Gesture history
  final List<String> _gestureHistory = [];
  static const int _maxHistory = 5;

  @override
  void initState() {
    super.initState();

    // Update UI periodically
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) {
        setState(() {
          _pitch = widget.controller.currentPitch;
          _relativePitch = widget.controller.relativePitch;
          _state = widget.controller.currentState;
        });
      }
    });

    // Subscribe to raw sensors if requested
    if (widget.showRawSensors) {
      _accelSubscription = accelerometerEventStream().listen((event) {
        if (mounted) {
          setState(() {
            _ax = event.x;
            _ay = event.y;
            _az = event.z;
          });
        }
      });

      _gyroSubscription = gyroscopeEventStream().listen((event) {
        if (mounted) {
          setState(() {
            _gx = event.x;
            _gy = event.y;
            _gz = event.z;
          });
        }
      }, onError: (_) {
        // Gyroscope not available
      });
    }

    // Listen for gestures
    widget.controller.gestureStream.listen((event) {
      if (mounted) {
        setState(() {
          _gestureHistory.insert(0,
              '${event.type.name.toUpperCase()} - ${_formatTime(event.timestamp)}');
          while (_gestureHistory.length > _maxHistory) {
            _gestureHistory.removeLast();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      left: 10,
      right: 10,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildStateIndicator(),
              const SizedBox(height: 12),
              _buildPitchInfo(),
              if (widget.showRawSensors) ...[
                const SizedBox(height: 12),
                _buildSensorData(),
              ],
              if (_gestureHistory.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildGestureHistory(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(Icons.bug_report, color: Colors.green, size: 20),
        SizedBox(width: 8),
        Text(
          'Motion Diagnostics',
          style: TextStyle(
            color: Colors.green,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildStateIndicator() {
    Color stateColor;
    String stateText;

    switch (_state) {
      case MotionState.neutral:
        stateColor = Colors.grey;
        stateText = 'NEUTRAL';
        break;
      case MotionState.fwdPending:
        stateColor = Colors.orange;
        stateText = 'FWD_PENDING';
        break;
      case MotionState.backPending:
        stateColor = Colors.orange;
        stateText = 'BACK_PENDING';
        break;
      case MotionState.cooldown:
        stateColor = Colors.red;
        stateText = 'COOLDOWN';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: stateColor.withOpacity(0.3),
        border: Border.all(color: stateColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'State: $stateText',
        style: TextStyle(
          color: stateColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildPitchInfo() {
    final pitchColor = _relativePitch.abs() > 20 ? Colors.yellow : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow('Pitch', '${_pitch.toStringAsFixed(1)}°', pitchColor),
        _buildDataRow(
            'Relative', '${_relativePitch.toStringAsFixed(1)}°', pitchColor),
        _buildPitchBar(),
      ],
    );
  }

  Widget _buildPitchBar() {
    // Visual bar showing pitch relative to thresholds
    const double barWidth = 200;
    const double barHeight = 20;

    // Normalize pitch to -1 to 1 range (assuming ±45° max)
    final normalizedPitch = (_relativePitch / 45).clamp(-1.0, 1.0);
    final indicatorPosition = (normalizedPitch + 1) * barWidth / 2;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: barWidth,
      height: barHeight,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey),
      ),
      child: Stack(
        children: [
          // Threshold markers
          Positioned(
            left: barWidth * 0.19, // -28° position
            top: 0,
            bottom: 0,
            child: Container(width: 2, color: Colors.red.withOpacity(0.5)),
          ),
          Positioned(
            left: barWidth * 0.81, // +28° position
            top: 0,
            bottom: 0,
            child: Container(width: 2, color: Colors.red.withOpacity(0.5)),
          ),
          // Center line
          Positioned(
            left: barWidth / 2 - 1,
            top: 0,
            bottom: 0,
            child: Container(width: 2, color: Colors.green),
          ),
          // Pitch indicator
          Positioned(
            left: indicatorPosition - 5,
            top: 2,
            bottom: 2,
            child: Container(
              width: 10,
              decoration: BoxDecoration(
                color: Colors.yellow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Raw Sensors:',
          style: TextStyle(
            color: Colors.green,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        _buildDataRow('Accel X', _ax.toStringAsFixed(2), Colors.white70),
        _buildDataRow('Accel Y', _ay.toStringAsFixed(2), Colors.white70),
        _buildDataRow('Accel Z', _az.toStringAsFixed(2), Colors.white70),
        _buildDataRow(
            'Gyro X', '${_gx.toStringAsFixed(2)} r/s', Colors.white70),
        _buildDataRow(
            'Gyro Y', '${_gy.toStringAsFixed(2)} r/s', Colors.white70),
        _buildDataRow(
            'Gyro Z', '${_gz.toStringAsFixed(2)} r/s', Colors.white70),
      ],
    );
  }

  Widget _buildGestureHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Gestures:',
          style: TextStyle(
            color: Colors.green,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        ..._gestureHistory.map((gesture) => Text(
              gesture,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            )),
      ],
    );
  }

  Widget _buildDataRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}
