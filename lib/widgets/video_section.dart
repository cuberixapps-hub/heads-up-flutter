import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import '../constants/app_theme.dart';
import '../models/video_recording_result.dart';
import '../providers/game_provider.dart';
import '../services/game_replay_renderer.dart';
import '../screens/video_player_with_overlay_screen.dart';
import '../services/video_composer.dart';
import '../services/haptic_service.dart';
import '../services/native_video_composer.dart';
import '../utils/video_utils.dart';
import 'video_with_overlay.dart';

class VideoSection extends StatefulWidget {
  const VideoSection({super.key});

  @override
  State<VideoSection> createState() => _VideoSectionState();
}

class _VideoSectionState extends State<VideoSection>
    with SingleTickerProviderStateMixin {
  final _hapticService = HapticService();

  VideoRecordingResult? _recordingResult;
  String? _composedVideoPath;
  String? _thumbnailPath;
  bool _isProcessingVideo = false;
  bool _videoProcessingFailed = false;
  List<String> _generatedFrames = [];
  late AnimationController _videoSectionController;

  // Progress tracking for FFmpeg
  final _progressController = StreamController<double>.broadcast();
  Stream<double> get _progressStream => _progressController.stream;

  @override
  void initState() {
    super.initState();
    debugPrint('VideoSection initState called');

    _videoSectionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Get video recording from provider
    final gameProvider = context.read<GameProvider>();
    _recordingResult = gameProvider.lastVideoRecording;
    debugPrint(
      'Video recording result: ${_recordingResult != null ? "Found" : "Not found"}',
    );

    // Debug current game session
    final currentSession = gameProvider.currentSession;
    debugPrint('Current session exists: ${currentSession != null}');
    if (currentSession != null) {
      debugPrint('Current session is complete: ${currentSession.isComplete}');
      debugPrint('Current session deck: ${currentSession.deck.name}');
    }

    if (_recordingResult != null) {
      debugPrint('Video path: ${_recordingResult!.videoPath}');
      debugPrint('Duration: ${_recordingResult!.duration}');

      // Check if video file exists
      final videoFile = File(_recordingResult!.videoPath);
      videoFile.exists().then((exists) {
        debugPrint('Video file exists: $exists');
        if (!exists) {
          debugPrint(
            'ERROR: Video file not found at path: ${_recordingResult!.videoPath}',
          );
        }
      });

      _processVideoRecording();
      _videoSectionController.forward();
    }
  }

  Future<void> _processVideoRecording() async {
    if (_recordingResult == null) return;

    setState(() {
      _isProcessingVideo = true;
      _videoProcessingFailed = false;
    });

    try {
      final gameProvider = context.read<GameProvider>();
      final session = gameProvider.currentSession;

      if (session == null) {
        throw Exception('No game session found');
      }

      debugPrint('=== VIDEO PROCESSING STARTED ===');
      debugPrint('Recording duration: ${_recordingResult!.duration}');
      debugPrint('Total events: ${_recordingResult!.events.length}');

      // Pre-generate all game replay frames to ensure smooth playback
      debugPrint('Pre-generating game replay frames...');
      final frames = await GameReplayRenderer.generateGameReplayFrames(
        recordingResult: _recordingResult!,
        deckColor: _getDeckColor(),
        gameDuration: _recordingResult!.duration,
      );

      if (frames.isEmpty) {
        debugPrint('Warning: No game replay frames generated');
      } else {
        debugPrint('Successfully generated ${frames.length} frames');

        // Store frames for later cleanup
        _generatedFrames = frames;
      }

      // Use the raw video path as we're doing dynamic overlay
      _composedVideoPath = _recordingResult!.videoPath;

      // Verify video file exists and is accessible
      final videoFile = File(_recordingResult!.videoPath);
      if (!await videoFile.exists()) {
        throw Exception('Video file not found');
      }

      final fileSize = await videoFile.length();
      debugPrint('Video file size: ${fileSize / 1024 / 1024} MB');

      // Try to generate thumbnail
      _thumbnailPath = await VideoComposer.generateThumbnail(
        _recordingResult!.videoPath,
      );

      setState(() {
        _isProcessingVideo = false;
      });

      debugPrint('=== VIDEO PROCESSING COMPLETE ===');
    } catch (e) {
      debugPrint('Video processing error: $e');
      setState(() {
        _isProcessingVideo = false;
        _videoProcessingFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _videoSectionController.dispose();
    _progressController.close();

    // Clean up generated frames
    if (_generatedFrames.isNotEmpty) {
      for (final frame in _generatedFrames) {
        try {
          File(frame).deleteSync();
        } catch (e) {
          // Ignore errors
        }
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'VideoSection build - Recording result: ${_recordingResult != null}',
    );
    if (_recordingResult == null) {
      debugPrint('VideoSection - No recording result, returning empty');
      // Show a placeholder message to debug
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.videocam_off, color: Colors.grey[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No reaction video recorded for this game',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    debugPrint('VideoSection - Has recording, showing video section');

    return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reaction',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your gameplay reactions captured!',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Video preview area
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                    ),

                    // Content based on state
                    if (_isProcessingVideo)
                      _buildProcessingView()
                    else if (_videoProcessingFailed)
                      _buildErrorView()
                    else if (_composedVideoPath != null)
                      _buildVideoPreview()
                    else
                      _buildRawVideoPreview(),
                  ],
                ),
              ),

              // Action buttons
              if (!_isProcessingVideo && _composedVideoPath != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.save_alt_rounded,
                          label: 'Save',
                          onTap: _saveVideo,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          onTap: _shareVideo,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          onTap: _deleteVideo,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        )
        .animate(controller: _videoSectionController)
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Creating your reaction video...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Video processing failed',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _playVideo(_recordingResult!.videoPath);
            },
            child: Text(
              'Watch original recording',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    // Use VideoWithOverlay for synchronized preview with pre-generated frames
    if (_recordingResult != null &&
        _composedVideoPath != null &&
        _generatedFrames.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          VideoWithOverlay(
            videoPath: _composedVideoPath!,
            recordingResult: _recordingResult!,
            deckColor: _getDeckColor(),
            onTap: () => _playVideo(_composedVideoPath!),
            autoPlay: false,
            preGeneratedFrames: _generatedFrames,
          ),

          // Duration badge
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(_recordingResult!.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Fallback to simple preview
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail or placeholder
        Container(
          color: Colors.black,
          child: const Icon(
            Icons.movie_outlined,
            color: Colors.white54,
            size: 64,
          ),
        ),

        // Dark overlay
        Container(color: Colors.black.withOpacity(0.3)),

        // Play button
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => _playVideo(_composedVideoPath!),
                customBorder: const CircleBorder(),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ),

        // Duration badge
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDuration(_recordingResult!.duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getDeckColor() {
    final gameProvider = context.read<GameProvider>();
    final session = gameProvider.currentSession;
    return session?.deck.color ?? AppTheme.primaryColor;
  }

  Widget _buildRawVideoPreview() {
    return _buildVideoPreview();
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            _hapticService.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playVideo(String videoPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => VideoPlayerWithOverlayScreen(
              videoPath: videoPath,
              title: 'Heads Up! - ${_recordingResult!.deckName}',
              recordingResult: _recordingResult!,
              deckColor: _getDeckColor(),
              preGeneratedFrames: _generatedFrames,
            ),
      ),
    );
  }

  Future<void> _saveVideo() async {
    if (_composedVideoPath == null) return;

    // Show options dialog
    final saveWithOverlay = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.darkSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Save Video',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How would you like to save the video?',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'reaction'),
                    icon: const Icon(Icons.person),
                    label: const Text('Reaction Only'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, 'screen_record'),
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('With Game Overlay'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use screen recording to capture both videos',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
    );

    if (saveWithOverlay == null) return;

    if (saveWithOverlay == 'reaction') {
      // Save reaction video directly
      final saved = await VideoUtils.saveVideoToGallery(_composedVideoPath!);

      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reaction video saved!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Try native composition first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppTheme.darkSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Creating video with overlay...',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<double>(
                    stream: _progressStream,
                    builder: (context, snapshot) {
                      final progress = snapshot.data ?? 0.0;
                      return LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
      );

      try {
        final compositeVideo =
            await NativeVideoComposer.composeVideoWithOverlay(
              reactionVideoPath: _composedVideoPath!,
              recordingResult: _recordingResult!,
              gameFrames: _generatedFrames,
              deckColor: _getDeckColor(),
              onProgress: (progress) {
                _progressController.add(progress);
              },
            );

        Navigator.pop(context); // Close progress dialog

        if (compositeVideo != null) {
          final saved = await VideoUtils.saveVideoToGallery(compositeVideo);

          if (saved && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Video saved with game overlay!'),
                  ],
                ),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          // Clean up composite video
          try {
            await File(compositeVideo).delete();
          } catch (e) {
            debugPrint('Error deleting composite video: $e');
          }
        } else {
          throw Exception('Native composition not available');
        }
      } catch (e) {
        Navigator.pop(context); // Close progress dialog

        // Fallback to screen recording instructions
        final proceed = await NativeVideoComposer.showCompositionInstructions(
          context,
        );

        if (proceed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Start screen recording now!'),
                ],
              ),
              backgroundColor: AppTheme.darkSecondary,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _shareVideo() async {
    if (_composedVideoPath == null) return;

    // Show share options dialog
    final shareOption = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.darkSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Share Video',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How would you like to share the video?',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'reaction'),
                    icon: const Icon(Icons.person),
                    label: const Text('Reaction Only'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, 'with_overlay'),
                    icon: const Icon(Icons.layers),
                    label: const Text('With Game Overlay'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );

    if (shareOption == null) return;

    final gameProvider = context.read<GameProvider>();
    final session = gameProvider.currentSession;

    if (session == null) return;

    if (shareOption == 'reaction') {
      // Share reaction video only
      await VideoUtils.shareVideo(
        videoPath: _composedVideoPath!,
        deckName: session.deck.name,
        score: session.totalScore,
        correctCount: session.correctCount,
        passCount: session.passCount,
      );
    } else {
      // Create composite video first, then share
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppTheme.darkSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Preparing video with overlay...',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<double>(
                    stream: _progressStream,
                    builder: (context, snapshot) {
                      final progress = snapshot.data ?? 0.0;
                      return LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
      );

      try {
        final compositeVideo =
            await NativeVideoComposer.composeVideoWithOverlay(
              reactionVideoPath: _composedVideoPath!,
              recordingResult: _recordingResult!,
              gameFrames: _generatedFrames,
              deckColor: _getDeckColor(),
              onProgress: (progress) {
                _progressController.add(progress);
              },
            );

        Navigator.pop(context); // Close progress dialog

        if (compositeVideo != null) {
          // Share the composite video
          await VideoUtils.shareVideo(
            videoPath: compositeVideo,
            deckName: session.deck.name,
            score: session.totalScore,
            correctCount: session.correctCount,
            passCount: session.passCount,
          );

          // Clean up composite video after sharing
          try {
            await File(compositeVideo).delete();
          } catch (e) {
            debugPrint('Error deleting composite video: $e');
          }
        } else {
          throw Exception('Failed to create composite video');
        }
      } catch (e) {
        Navigator.pop(context); // Close progress dialog

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to prepare video. Sharing reaction only.'),
              backgroundColor: AppTheme.warningColor,
            ),
          );

          // Fallback to sharing reaction video only
          await VideoUtils.shareVideo(
            videoPath: _composedVideoPath!,
            deckName: session.deck.name,
            score: session.totalScore,
            correctCount: session.correctCount,
            passCount: session.passCount,
          );
        }
      }
    }
  }

  Future<void> _deleteVideo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Video?'),
            content: const Text(
              'This will permanently delete the reaction video.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      // Delete video files
      if (_composedVideoPath != null) {
        await VideoUtils.deleteTemporaryVideo(_composedVideoPath!);
      }
      if (_recordingResult != null) {
        await VideoUtils.deleteTemporaryVideo(_recordingResult!.videoPath);
      }
      if (_thumbnailPath != null) {
        await VideoUtils.deleteTemporaryVideo(_thumbnailPath!);
      }

      // Clear from provider
      context.read<GameProvider>().clearVideoRecording();

      // Hide video section
      await _videoSectionController.reverse();
      setState(() {
        _recordingResult = null;
        _composedVideoPath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Video deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
