import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/video_recording_result.dart';

class CameraRecordingService {
  static CameraRecordingService? _instance;
  static CameraRecordingService get instance {
    _instance ??= CameraRecordingService._();
    return _instance!;
  }

  CameraRecordingService._();

  CameraController? _controller;
  List<GameEvent> _gameEvents = [];
  DateTime? _recordingStartTime;
  String? _currentVideoPath;
  bool _isRecording = false;
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  CameraController? get controller => _controller;

  // Initialize camera (front-facing)
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Camera init logs kept minimal
      // Permissions are expected to be granted before reaching this point
      // (handled by GameplayPermissionsScreen). If not, this will silently fail.
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        return false;
      }

      // Find front camera
      CameraDescription? frontCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      // Fallback to first camera if no front camera
      frontCamera ??= cameras.first;

      // Determine resolution based on device capability
      // Using high instead of max to ensure compatibility
      ResolutionPreset resolution = ResolutionPreset.high;

      // Create camera controller
      final controller = CameraController(
        frontCamera,
        resolution,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;

      // Initialize controller
      await controller.initialize();

      // Lock capture to landscape so recorded video is always landscape
      // (gameplay screen is in landscape; portrait capture causes black bars on results)
      try {
        await controller.lockCaptureOrientation(
          DeviceOrientation.landscapeLeft,
        );
      } catch (e) {
        debugPrint('Could not lock capture orientation to landscape: $e');
      }

      _isInitialized = true;

      // Prepare for video recording
      await controller.prepareForVideoRecording();

      return true;
    } catch (e) {
      debugPrint('Camera initialization failed: $e');

      // Check if it's a permission error
      if (e.toString().contains('Camera access') ||
          e.toString().contains('permission') ||
          e.toString().contains('authorized')) {
        debugPrint('Camera permission was denied');
      }

      _isInitialized = false;
      return false;
    }
  }

  // Start recording when game starts
  Future<bool> startRecording(String deckName, String deckColor) async {
    if (!_isInitialized || _controller == null) {
      return false;
    }

    if (_isRecording) {
      return true;
    }

    try {
      // Create file path
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentVideoPath = '${directory.path}/reaction_$timestamp.mp4';

      // Start video recording
      await _controller!.startVideoRecording();

      // Initialize recording data
      _recordingStartTime = DateTime.now();
      _isRecording = true;
      _gameEvents.clear();

      // Log game start event (don't use deck name as word)
      logGameEvent(type: 'game_start', word: '', score: 0, remainingTime: null);

      return true;
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      _isRecording = false;
      return false;
    }
  }

  // Log game events (word shown, correct/pass)
  void logGameEvent({
    required String type,
    required String word,
    required int score,
    Duration? remainingTime,
  }) {
    if (!_isRecording || _recordingStartTime == null) return;

    final event = GameEvent(
      timestamp: DateTime.now().difference(_recordingStartTime!),
      type: type,
      word: word,
      score: score,
      remainingTime: remainingTime,
    );

    _gameEvents.add(event);
  }

  // Stop recording and return video path
  Future<VideoRecordingResult?> stopRecording(
    String deckName,
    String deckColor,
  ) async {
    if (!_isRecording || _controller == null) {
      debugPrint('Not recording');
      return null;
    }

    final recordingStart = _recordingStartTime;

    try {
      // Log game end event
      logGameEvent(
        type: 'game_end',
        word: '',
        score: _gameEvents.isNotEmpty ? _gameEvents.last.score : 0,
        remainingTime: Duration.zero,
      );

      // Stop video recording
      final videoFile = await _controller!.stopVideoRecording();
      _isRecording = false;

      // Verify file exists
      final file = File(videoFile.path);
      final exists = await file.exists();

      // Calculate duration
      final duration = DateTime.now().difference(
        recordingStart ?? DateTime.now(),
      );

      // Create result
      final result = VideoRecordingResult(
        videoPath: videoFile.path,
        events: List.from(_gameEvents),
        duration: duration,
        recordingStartTime: recordingStart ?? DateTime.now(),
        deckName: deckName,
        deckColor: deckColor,
      );

      // Clear recording data
      _gameEvents.clear();
      _recordingStartTime = null;
      _currentVideoPath = null;

      return result;
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
      _isRecording = false;

      // Don't dispose camera here - let the app handle it separately

      return null;
    }
  }

  // Clean up temporary video file
  Future<void> deleteTemporaryVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting temp video: $e');
    }
  }

  // Dispose camera resources
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isRecording = false;
    _gameEvents.clear();
  }

  // Release camera without affecting recorded video
  Future<void> releaseCamera() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
    }
  }

  // Get recording quality based on device
  ResolutionPreset getOptimalResolution() {
    // Using high quality for better compatibility
    return ResolutionPreset.high;
  }
}
