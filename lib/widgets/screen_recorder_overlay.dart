import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_theme.dart';

class ScreenRecorderOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback? onRecordingComplete;

  const ScreenRecorderOverlay({
    super.key,
    required this.child,
    this.onRecordingComplete,
  });

  @override
  State<ScreenRecorderOverlay> createState() => _ScreenRecorderOverlayState();
}

class _ScreenRecorderOverlayState extends State<ScreenRecorderOverlay> {
  bool _showInstructions = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    // Show instructions after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showInstructions = true;
        });
      }
    });
  }

  void _startScreenRecording() {
    setState(() {
      _showInstructions = false;
      _isRecording = true;
    });

    // Show recording indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .fade(begin: 1, end: 0.3, duration: 1.seconds)
                .then()
                .fade(begin: 0.3, end: 1, duration: 1.seconds),
            const SizedBox(width: 12),
            const Text('Screen recording active - Play the video now'),
          ],
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: AppTheme.darkSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Instructions overlay
        if (_showInstructions && !_isRecording)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 20,
            right: 20,
            child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkPrimary.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            color: AppTheme.primaryColor,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Record Complete Video',
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showInstructions = false;
                              });
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        Platform.isIOS
                            ? 'To save the video with game overlay:\n\n'
                                '1. Swipe down from top-right corner\n'
                                '2. Tap the screen record button 🔴\n'
                                '3. Start playing the video\n'
                                '4. Stop recording when done\n'
                                '5. Video saves to Photos app'
                            : 'To save the video with game overlay:\n\n'
                                '1. Swipe down to open quick settings\n'
                                '2. Tap "Screen record" 🔴\n'
                                '3. Start playing the video\n'
                                '4. Stop recording when done\n'
                                '5. Video saves to Gallery',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _showInstructions = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white30),
                              ),
                              child: const Text('Dismiss'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _startScreenRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                              ),
                              child: const Text('Got it!'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: -0.2, end: 0, duration: 300.ms),
          ),
      ],
    );
  }
}
