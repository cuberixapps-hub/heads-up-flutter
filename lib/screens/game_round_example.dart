import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../motion/heads_up_motion_controller.dart';
import '../motion/motion_config.dart';
import '../motion/motion_diagnostics.dart';
import '../motion/motion_classifier.dart';

/// Example game round page demonstrating motion detection usage
///
/// This is a minimal example showing how to integrate the motion
/// detection system into a game screen.
class GameRoundExample extends StatefulWidget {
  const GameRoundExample({Key? key}) : super(key: key);

  @override
  State<GameRoundExample> createState() => _GameRoundExampleState();
}

class _GameRoundExampleState extends State<GameRoundExample> {
  late HeadsUpMotionController _motionController;

  // Game state
  int _correctCount = 0;
  int _passCount = 0;
  String _currentWord = 'Example Word';
  String _lastAction = 'Ready';
  bool _isCalibrating = true;
  bool _showDebugOverlay = true;

  // Example word list
  final List<String> _words = [
    'Pizza',
    'Elephant',
    'Smartphone',
    'Bicycle',
    'Rainbow',
    'Guitar',
    'Ocean',
    'Mountain',
    'Coffee',
    'Airplane',
  ];
  int _wordIndex = 0;

  @override
  void initState() {
    super.initState();

    // Lock to landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize motion controller with custom config
    _motionController = HeadsUpMotionController(
      config: const MotionConfig(
        // You can customize thresholds here
        forwardEnterDeg: -25.0, // Slightly easier than default
        backEnterDeg: 25.0,
        holdMs: 100, // Slightly faster response
      ),
    );

    // Enable debug mode
    _motionController.debugMode = true;

    // Start motion detection
    _startMotionDetection();
  }

  @override
  void dispose() {
    // Clean up
    _motionController.dispose();

    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  Future<void> _startMotionDetection() async {
    // Show calibration message
    setState(() {
      _isCalibrating = true;
      _lastAction = 'Calibrating... Hold phone at forehead';
    });

    // Start motion detection
    await _motionController.start(
      onCorrect: _handleCorrect,
      onPass: _handlePass,
    );

    // Calibration takes ~500ms
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isCalibrating = false;
      _lastAction = 'Ready - Tilt to play!';
    });
  }

  void _handleCorrect() {
    setState(() {
      _correctCount++;
      _lastAction = 'CORRECT! ✓';
      _nextWord();
    });

    // Log for debugging
    debugPrint('GameRound: Correct detected! Total: $_correctCount');
  }

  void _handlePass() {
    setState(() {
      _passCount++;
      _lastAction = 'PASS →';
      _nextWord();
    });

    // Log for debugging
    debugPrint('GameRound: Pass detected! Total: $_passCount');
  }

  void _nextWord() {
    setState(() {
      _wordIndex = (_wordIndex + 1) % _words.length;
      _currentWord = _words[_wordIndex];
    });
  }

  void _recalibrate() async {
    setState(() {
      _isCalibrating = true;
      _lastAction = 'Recalibrating...';
    });

    await _motionController.recalibrate();
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isCalibrating = false;
      _lastAction = 'Recalibration complete!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main game UI
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Score display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildScoreCard('CORRECT', _correctCount, Colors.green),
                      const SizedBox(width: 40),
                      _buildScoreCard('PASS', _passCount, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Current word
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _currentWord,
                      key: ValueKey(_currentWord),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status/Action indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: _getActionColor(),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _lastAction,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isCalibrating ? null : _recalibrate,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recalibrate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showDebugOverlay = !_showDebugOverlay;
                          });
                        },
                        icon: Icon(_showDebugOverlay
                            ? Icons.bug_report
                            : Icons.bug_report_outlined),
                        label: Text(
                            _showDebugOverlay ? 'Hide Debug' : 'Show Debug'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  // Instructions
                  if (_isCalibrating) ...[
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    const Text(
                      'Hold phone at forehead in landscape mode',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Debug overlay
          if (_showDebugOverlay)
            MotionDiagnosticsOverlay(
              controller: _motionController,
              showRawSensors: true,
            ),

          // Back button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, int score, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            score.toString(),
            style: TextStyle(
              color: color,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getActionColor() {
    if (_isCalibrating) return Colors.blue;
    if (_lastAction.contains('CORRECT')) return Colors.green;
    if (_lastAction.contains('PASS')) return Colors.orange;
    return Colors.grey;
  }
}
