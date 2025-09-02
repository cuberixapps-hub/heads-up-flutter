import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/game_provider.dart';
import '../services/camera_recording_service.dart';
import '../screens/video_player_screen.dart';

class VideoDebugScreen extends StatefulWidget {
  const VideoDebugScreen({super.key});

  @override
  State<VideoDebugScreen> createState() => _VideoDebugScreenState();
}

class _VideoDebugScreenState extends State<VideoDebugScreen> {
  final _cameraService = CameraRecordingService.instance;
  String _status = 'Checking...';
  List<String> _debugInfo = [];

  @override
  void initState() {
    super.initState();
    _checkEverything();
  }

  Future<void> _checkEverything() async {
    _debugInfo.clear();

    // Check camera service
    _addDebug('Camera Service Status:');
    _addDebug('- Initialized: ${_cameraService.isInitialized}');
    _addDebug('- Recording: ${_cameraService.isRecording}');

    // Check game provider
    final gameProvider = context.read<GameProvider>();
    final recording = gameProvider.lastVideoRecording;

    _addDebug('\nGameProvider Status:');
    _addDebug('- Has recording: ${recording != null}');

    if (recording != null) {
      _addDebug('- Video path: ${recording.videoPath}');
      _addDebug('- Duration: ${recording.duration}');
      _addDebug('- Events: ${recording.events.length}');

      // Check file
      final file = File(recording.videoPath);
      final exists = await file.exists();
      _addDebug('- File exists: $exists');

      if (exists) {
        final size = await file.length();
        _addDebug('- File size: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
      }
    }

    // Test recording
    _addDebug('\nTesting Camera Recording:');

    setState(() {
      _status = 'Debug info collected';
    });
  }

  void _addDebug(String message) {
    setState(() {
      _debugInfo.add(message);
    });
    debugPrint('VideoDebug: $message');
  }

  Future<void> _testRecording() async {
    _addDebug('\nStarting test recording...');

    // Initialize if needed
    if (!_cameraService.isInitialized) {
      _addDebug('Initializing camera...');
      final initialized = await _cameraService.initialize();
      _addDebug('Camera initialized: $initialized');

      if (!initialized) {
        _addDebug('ERROR: Failed to initialize camera');
        return;
      }
    }

    // Start recording
    _addDebug('Starting recording...');
    final started = await _cameraService.startRecording('Test', 'Blue');
    _addDebug('Recording started: $started');

    if (!started) {
      _addDebug('ERROR: Failed to start recording');
      return;
    }

    // Record for 3 seconds
    _addDebug('Recording for 3 seconds...');
    await Future.delayed(const Duration(seconds: 3));

    // Stop recording
    _addDebug('Stopping recording...');
    final result = await _cameraService.stopRecording('Test', 'Blue');

    if (result != null) {
      _addDebug('Recording successful!');
      _addDebug('- Path: ${result.videoPath}');
      _addDebug('- Duration: ${result.duration}');

      // Check file
      final file = File(result.videoPath);
      final exists = await file.exists();
      _addDebug('- File exists: $exists');

      if (exists) {
        final size = await file.length();
        _addDebug('- File size: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');

        // Store in provider
        _addDebug('Storing in GameProvider...');
        context.read<GameProvider>().setVideoRecording(result);
        _addDebug('Stored successfully!');
      }
    } else {
      _addDebug('ERROR: Recording failed - result is null');
    }
  }

  void _playVideo(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                VideoPlayerScreen(videoPath: path, title: 'Debug Video'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recording = context.watch<GameProvider>().lastVideoRecording;

    return Scaffold(
      appBar: AppBar(title: const Text('Video Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _status,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _checkEverything,
                  child: const Text('Refresh'),
                ),
                ElevatedButton(
                  onPressed: _testRecording,
                  child: const Text('Test Recording'),
                ),
                if (recording != null)
                  ElevatedButton(
                    onPressed: () => _playVideo(recording.videoPath),
                    child: const Text('Play Video'),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Debug info
            Expanded(
              child: ListView.builder(
                itemCount: _debugInfo.length,
                itemBuilder: (context, index) {
                  return Text(
                    _debugInfo[index],
                    style: const TextStyle(fontFamily: 'monospace'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
