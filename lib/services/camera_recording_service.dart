import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
      debugPrint('Initializing camera service...');

      // Get available cameras
      // This will automatically trigger permission dialogs on iOS
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
      ResolutionPreset resolution = ResolutionPreset.high;

      // Create camera controller
      _controller = CameraController(
        frontCamera,
        resolution,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Initialize controller
      await _controller!.initialize();

      _isInitialized = true;
      debugPrint('Camera initialized successfully');
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
      debugPrint('Camera not initialized');
      return false;
    }

    if (_isRecording) {
      debugPrint('Already recording');
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

      debugPrint('Recording started: $_currentVideoPath');
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
    debugPrint('=== GAME EVENT LOGGED ===');
    debugPrint('Event type: $type');
    debugPrint('Word: "$word"');
    debugPrint('Score: $score');
    debugPrint('Timestamp: ${event.timestamp.inSeconds}s');
    debugPrint('Total events so far: ${_gameEvents.length}');
    
    // Debug all events
    if (type == 'word_shown') {
      debugPrint('All events:');
      for (var e in _gameEvents) {
        debugPrint('  ${e.type}: "${e.word}" at ${e.timestamp.inSeconds}s');
      }
    }
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

      debugPrint('Video file path from controller: ${videoFile.path}');

      // Check if file exists
      final file = File(videoFile.path);
      final exists = await file.exists();
      debugPrint('Video file exists after recording: $exists');
      if (exists) {
        final fileSize = await file.length();
        debugPrint('Video file size: ${fileSize / 1024 / 1024} MB');
      }

      // Calculate duration
      final duration = DateTime.now().difference(_recordingStartTime!);

      // Create result
      final result = VideoRecordingResult(
        videoPath: videoFile.path,
        events: List.from(_gameEvents),
        duration: duration,
        recordingStartTime: _recordingStartTime!,
        deckName: deckName,
        deckColor: deckColor,
      );

      debugPrint('Recording stopped. Duration: ${duration.inSeconds}s');
      debugPrint('Video saved to: ${videoFile.path}');
      debugPrint('Total events logged: ${_gameEvents.length}');

      // Clear recording data
      _gameEvents.clear();
      _recordingStartTime = null;
      _currentVideoPath = null;

      return result;
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  // Clean up temporary video file
  Future<void> deleteTemporaryVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Temporary video deleted: $videoPath');
      }
    } catch (e) {
      debugPrint('Error deleting temporary video: $e');
    }
  }

  // Dispose camera resources
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isRecording = false;
    _gameEvents.clear();
    debugPrint('Camera recording service disposed');
  }

  // Get recording quality based on device
  ResolutionPreset getOptimalResolution() {
    // You can implement device capability detection here
    // For now, default to high quality
    return ResolutionPreset.high;
  }
}
