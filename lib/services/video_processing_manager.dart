import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/video_recording_result.dart';
import 'game_replay_renderer.dart';
import 'video_composer.dart';

/// Cancellation token for video processing operations.
/// Check [isCancelled] periodically during long-running operations.
class VideoCancellationToken {
  bool _isCancelled = false;
  final String sessionId;
  final DateTime createdAt;

  VideoCancellationToken({required this.sessionId})
      : createdAt = DateTime.now();

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
    // Token cancelled
  }

  @override
  String toString() =>
      'VideoCancellationToken(sessionId: $sessionId, isCancelled: $_isCancelled)';
}

/// Result of video processing operation
class VideoProcessingResult {
  final bool success;
  final bool wasCancelled;
  final List<String> generatedFrames;
  final String? composedVideoPath;
  final String? thumbnailPath;
  final String? error;

  VideoProcessingResult({
    required this.success,
    this.wasCancelled = false,
    this.generatedFrames = const [],
    this.composedVideoPath,
    this.thumbnailPath,
    this.error,
  });

  factory VideoProcessingResult.cancelled() => VideoProcessingResult(
        success: false,
        wasCancelled: true,
      );

  factory VideoProcessingResult.error(String message) => VideoProcessingResult(
        success: false,
        error: message,
      );
}

/// Manages video processing lifecycle across the app.
/// 
/// This singleton handles:
/// - Cancellation when navigating away from results screen
/// - Cancellation when app goes to background
/// - Cancellation when a new game starts
/// - Cleanup of generated frames when processing is cancelled
class VideoProcessingManager with WidgetsBindingObserver {
  static final VideoProcessingManager _instance =
      VideoProcessingManager._internal();
  static VideoProcessingManager get instance => _instance;

  VideoProcessingManager._internal() {
    // Register as lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    // VideoProcessingManager initialized
  }

  /// Current cancellation token for active processing
  VideoCancellationToken? _currentToken;

  /// Whether processing is currently active
  bool _isProcessing = false;

  /// Stream controller for processing state changes
  final _processingStateController = StreamController<bool>.broadcast();

  /// Stream of processing state changes
  Stream<bool> get processingStateStream => _processingStateController.stream;

  /// Whether processing is currently active
  bool get isProcessing => _isProcessing;

  /// Current session ID being processed
  String? get currentSessionId => _currentToken?.sessionId;

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // App is going to background - cancel any active processing
      cancelCurrentProcessing(reason: 'App moved to background ($state)');
    }
  }

  /// Start video processing with a unique session ID.
  /// 
  /// Returns a [VideoCancellationToken] that can be used to check if
  /// processing should continue. The caller should check [token.isCancelled]
  /// periodically during long-running operations.
  /// 
  /// If there's already processing for a different session, it will be cancelled.
  VideoCancellationToken startProcessing(String sessionId) {
    // Cancel any existing processing for a different session
    if (_currentToken != null && _currentToken!.sessionId != sessionId) {
      // Cancelling previous session
      _currentToken!.cancel();
    }

    // Create new token
    _currentToken = VideoCancellationToken(sessionId: sessionId);
    _isProcessing = true;
    _processingStateController.add(true);

    // Started video processing
    return _currentToken!;
  }

  /// Cancel current video processing.
  /// 
  /// [reason] is logged for debugging purposes.
  void cancelCurrentProcessing({String reason = 'Manual cancellation'}) {
    if (_currentToken != null && !_currentToken!.isCancelled) {
      // Cancelling video processing
      _currentToken!.cancel();
    }
    _isProcessing = false;
    _processingStateController.add(false);
  }

  /// Cancel processing for a specific session.
  void cancelProcessingForSession(String sessionId) {
    if (_currentToken != null && _currentToken!.sessionId == sessionId) {
      cancelCurrentProcessing(reason: 'Session $sessionId cancelled');
    }
  }

  /// Mark processing as complete for a session.
  void completeProcessing(String sessionId) {
    if (_currentToken != null && _currentToken!.sessionId == sessionId) {
      // Processing completed
      _isProcessing = false;
      _processingStateController.add(false);
    }
  }

  /// Process video recording with full cancellation support.
  /// 
  /// This is the main entry point for video processing that handles:
  /// - Frame generation with cancellation checks
  /// - Thumbnail generation
  /// - Cleanup on cancellation
  Future<VideoProcessingResult> processVideoRecording({
    required VideoRecordingResult recordingResult,
    required Color deckColor,
    required String sessionId,
    void Function(double progress)? onProgress,
  }) async {
    final token = startProcessing(sessionId);

    try {
      // Check if already cancelled
      if (token.isCancelled) {
        return VideoProcessingResult.cancelled();
      }

      // Video processing started

      // Generate game replay frames with cancellation support
      // Frame generation is ~90% of total work
      final frames = await GameReplayRenderer.generateGameReplayFramesWithCancellation(
        recordingResult: recordingResult,
        deckColor: deckColor,
        gameDuration: recordingResult.duration,
        cancellationToken: token,
        onProgress: onProgress != null
            ? (p) => onProgress(p * 0.9)
            : null,
      );

      // Check if cancelled during frame generation
      if (token.isCancelled) {
        // Clean up any generated frames
        await _cleanupFrames(frames);
        return VideoProcessingResult.cancelled();
      }

      // Frames generation done

      // Use the raw video path as we're doing dynamic overlay
      final composedVideoPath = recordingResult.videoPath;

      // Verify video file exists and is accessible
      final videoFile = File(recordingResult.videoPath);
      if (!await videoFile.exists()) {
        return VideoProcessingResult.error('Video file not found');
      }

      // Check if cancelled before thumbnail generation
      if (token.isCancelled) {
        await _cleanupFrames(frames);
        return VideoProcessingResult.cancelled();
      }

      onProgress?.call(0.95);

      // Generate thumbnail
      String? thumbnailPath;
      try {
        thumbnailPath = await VideoComposer.generateThumbnail(
          recordingResult.videoPath,
        );
      } catch (e) {
        // Thumbnail generation failed, continuing without it
        // Continue without thumbnail
      }

      // Check if cancelled after thumbnail
      if (token.isCancelled) {
        await _cleanupFrames(frames);
        return VideoProcessingResult.cancelled();
      }

      onProgress?.call(1.0);
      completeProcessing(sessionId);

      return VideoProcessingResult(
        success: true,
        generatedFrames: frames,
        composedVideoPath: composedVideoPath,
        thumbnailPath: thumbnailPath,
      );
    } catch (e) {
      debugPrint('Video processing error: $e');
      cancelCurrentProcessing(reason: 'Error: $e');
      return VideoProcessingResult.error(e.toString());
    }
  }

  /// Cleanup generated frames
  Future<void> _cleanupFrames(List<String> frames) async {
    if (frames.isEmpty) return;
    
    for (final frame in frames) {
      try {
        final file = File(frame);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Cleanup frames synchronously (for dispose)
  void cleanupFramesSync(List<String> frames) {
    if (frames.isEmpty) return;
    
    // Cleanup frames sync
    for (final frame in frames) {
      try {
        File(frame).deleteSync();
      } catch (e) {
        // Ignore errors during sync cleanup
      }
    }
  }

  /// Dispose the manager (should only be called when app is terminating)
  void dispose() {
    cancelCurrentProcessing(reason: 'Manager disposed');
    WidgetsBinding.instance.removeObserver(this);
    _processingStateController.close();
    // Manager disposed
  }
}
