import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import '../constants/app_theme.dart';
import '../models/video_recording_result.dart';
import '../providers/game_provider.dart';
import '../screens/video_player_with_overlay_screen.dart';
import '../services/haptic_service.dart';
import '../services/native_video_composer.dart';
import '../services/video_processing_manager.dart';
import '../utils/responsive.dart';
import '../utils/video_utils.dart';
import 'video_with_overlay.dart';

class VideoSection extends StatefulWidget {
  final VoidCallback? onNavigateAway;
  
  const VideoSection({super.key, this.onNavigateAway});

  @override
  State<VideoSection> createState() => VideoSectionState();
}

class VideoSectionState extends State<VideoSection>
    with SingleTickerProviderStateMixin {
  final _hapticService = HapticService();
  final _videoProcessingManager = VideoProcessingManager.instance;

  VideoRecordingResult? _recordingResult;
  String? _composedVideoPath;
  String? _thumbnailPath;
  bool _isProcessingVideo = false;
  bool _videoProcessingFailed = false;
  List<String> _generatedFrames = [];
  late AnimationController _videoSectionController;
  
  // Unique session ID for this video processing
  String? _sessionId;

  // Progress tracking for FFmpeg
  final _progressController = StreamController<double>.broadcast();
  Stream<double> get _progressStream => _progressController.stream;
  
  // Public method to cancel video processing
  void cancelVideoProcessing() {
    debugPrint('📹 VideoSection: cancellation requested');
    if (_sessionId != null) {
      _videoProcessingManager.cancelProcessingForSession(_sessionId!);
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('📹 VideoSection initState called');

    _videoSectionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Get video recording from provider
    final gameProvider = context.read<GameProvider>();
    _recordingResult = gameProvider.lastVideoRecording;
    debugPrint(
      '📹 Video recording result: ${_recordingResult != null ? "Found" : "Not found"}',
    );

    // Debug current game session
    final currentSession = gameProvider.currentSession;
    debugPrint('📹 Current session exists: ${currentSession != null}');
    if (currentSession != null) {
      debugPrint('📹 Current session is complete: ${currentSession.isComplete}');
      debugPrint('📹 Current session deck: ${currentSession.deck.name}');
      
      // Generate unique session ID based on session data
      _sessionId = '${currentSession.deck.id}_${DateTime.now().millisecondsSinceEpoch}';
    }

    if (_recordingResult != null) {
      debugPrint('📹 Video path: ${_recordingResult!.videoPath}');
      debugPrint('📹 Duration: ${_recordingResult!.duration}');

      // Check if video file exists
      final videoFile = File(_recordingResult!.videoPath);
      videoFile.exists().then((exists) {
        debugPrint('📹 Video file exists: $exists');
        if (!exists) {
          debugPrint(
            '📹 ERROR: Video file not found at path: ${_recordingResult!.videoPath}',
          );
        }
      });

      _processVideoRecording();
      _videoSectionController.forward();
    }
  }

  Future<void> _processVideoRecording() async {
    if (_recordingResult == null || _sessionId == null) return;

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

      // Use the VideoProcessingManager for processing with proper cancellation
      final result = await _videoProcessingManager.processVideoRecording(
        recordingResult: _recordingResult!,
        deckColor: _getDeckColor(),
        sessionId: _sessionId!,
      );

      // Check if we're still mounted
      if (!mounted) return;

      if (result.wasCancelled) {
        debugPrint('📹 Video processing was cancelled');
        setState(() {
          _isProcessingVideo = false;
        });
        return;
      }

      if (!result.success) {
        debugPrint('📹 Video processing failed: ${result.error}');
        setState(() {
          _isProcessingVideo = false;
          _videoProcessingFailed = true;
        });
        return;
      }

      // Store the results
      _generatedFrames = result.generatedFrames;
      _composedVideoPath = result.composedVideoPath;
      _thumbnailPath = result.thumbnailPath;

      final fileSize = await File(_recordingResult!.videoPath).length();
      debugPrint('📹 Video file size: ${fileSize / 1024 / 1024} MB');

      setState(() {
        _isProcessingVideo = false;
      });

      debugPrint('📹 === VIDEO PROCESSING COMPLETE ===');
    } catch (e) {
      debugPrint('📹 Video processing error: $e');
      if (mounted) {
        setState(() {
          _isProcessingVideo = false;
          _videoProcessingFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    debugPrint('📹 VideoSection dispose');
    
    // Cancel any ongoing video processing for this session
    if (_sessionId != null) {
      _videoProcessingManager.cancelProcessingForSession(_sessionId!);
    }
    
    _videoSectionController.dispose();
    _progressController.close();

    // Clean up generated frames
    if (_generatedFrames.isNotEmpty) {
      debugPrint('📹 VideoSection dispose - cleaning up ${_generatedFrames.length} frames');
      _videoProcessingManager.cleanupFramesSync(_generatedFrames);
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
      return Container(
        margin: EdgeInsets.symmetric(vertical: 12.s),
        padding: EdgeInsets.all(18.s),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18.s),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44.s,
              height: 44.s,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.s),
              ),
              child: Icon(
                Icons.videocam_off_rounded,
                color: Colors.white.withOpacity(0.8),
                size: 22.s,
              ),
            ),
            SizedBox(width: 14.s),
            Expanded(
              child: Text(
                'No reaction video recorded for this game',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    debugPrint('VideoSection - Has recording, showing video section');

    final deckColor = _getDeckColor();
    return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24.s),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          ),
          child: Column(
            children: [
              // Header - dark theme
              Container(
                padding: EdgeInsets.all(20.s),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48.s,
                      height: 48.s,
                      decoration: BoxDecoration(
                        color: deckColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12.s),
                        border: Border.all(
                          color: deckColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.videocam_rounded,
                        color: deckColor,
                        size: 24.s,
                      ),
                    ),
                    SizedBox(width: 16.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reaction',
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.s),
                          Text(
                            'Your gameplay reactions captured!',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: Colors.white.withOpacity(0.65),
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
                    // Background - dark
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                      ),
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
                  padding: EdgeInsets.all(16.s),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                        width: 1,
                      ),
                    ),
                  ),
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
    final deckColor = _getDeckColor();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 56.s,
            height: 56.s,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                deckColor,
              ),
            ),
          ),
          SizedBox(height: 18.s),
          Text(
            'Creating your reaction video...',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8.s),
          Text(
            'This may take a few seconds',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    final deckColor = _getDeckColor();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48.s,
            color: AppTheme.errorColor,
          ),
          SizedBox(height: 16.s),
          Text(
            'Video processing failed',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.s),
          TextButton(
            onPressed: () {
              _playVideo(_recordingResult!.videoPath);
            },
            style: TextButton.styleFrom(
              foregroundColor: deckColor,
            ),
            child: Text(
              'Watch original recording',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: deckColor,
              ),
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
            bottom: 16.s,
            right: 16.s,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 6.s),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10.s),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: Colors.white,
                    size: 16.s,
                  ),
                  SizedBox(width: 6.s),
                  Text(
                    _formatDuration(_recordingResult!.duration),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13.sp,
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

    // Fallback to simple preview - dark theme
    final deckColor = _getDeckColor();
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black,
          child: Icon(
            Icons.movie_outlined,
            color: Colors.white.withOpacity(0.4),
            size: 64.s,
          ),
        ),
        Container(color: Colors.black.withOpacity(0.3)),
        Center(
          child: Container(
            width: 72.s,
            height: 72.s,
            decoration: BoxDecoration(
              color: deckColor.withOpacity(0.9),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: deckColor.withOpacity(0.4),
                  blurRadius: 20.s,
                  offset: Offset(0, 6.s),
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
                  size: 44.s,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16.s,
          right: 16.s,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 6.s),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10.s),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Text(
              _formatDuration(_recordingResult!.duration),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12.sp,
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
      height: 48.s,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14.s),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14.s),
        child: InkWell(
          onTap: () {
            _hapticService.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(14.s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20.s),
              SizedBox(width: 8.s),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 14.sp,
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
