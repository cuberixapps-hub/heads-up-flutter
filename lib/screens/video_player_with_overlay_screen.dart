import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../constants/app_theme.dart';
import '../services/haptic_service.dart';
import '../models/video_recording_result.dart';
import '../services/game_replay_renderer.dart';
import '../services/native_video_composer.dart';
import '../widgets/video_overlay_frame_manager.dart';
import '../widgets/screen_recorder_overlay.dart';
import '../utils/video_utils.dart';

class VideoPlayerWithOverlayScreen extends StatefulWidget {
  final String videoPath;
  final String title;
  final VideoRecordingResult recordingResult;
  final Color deckColor;
  final List<String>? preGeneratedFrames;

  const VideoPlayerWithOverlayScreen({
    super.key,
    required this.videoPath,
    required this.title,
    required this.recordingResult,
    required this.deckColor,
    this.preGeneratedFrames,
  });

  @override
  State<VideoPlayerWithOverlayScreen> createState() =>
      _VideoPlayerWithOverlayScreenState();
}

class _VideoPlayerWithOverlayScreenState
    extends State<VideoPlayerWithOverlayScreen> {
  final _hapticService = HapticService();
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  List<String> _gameFrames = [];
  int _currentFrameIndex = 0;
  bool _isGeneratingFrames = false;
  String? _generationError;
  VideoOverlayFrameManager? _frameManager;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeVideo();
    _generateGameFrames();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      await _controller!.initialize();

      // Update frame based on video position
      _controller!.addListener(() {
        if (_controller!.value.isPlaying && _gameFrames.isNotEmpty) {
          final position = _controller!.value.position;
          // Calculate frame index for 30 FPS
          final frameIndex = (position.inMilliseconds * 30 / 1000).floor();

          if (frameIndex != _currentFrameIndex &&
              frameIndex >= 0 &&
              frameIndex < _gameFrames.length) {
            setState(() {
              _currentFrameIndex = frameIndex;
            });

            // Preload nearby frames
            _frameManager?.preloadFrames(frameIndex);
          }
        }
      });

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  Future<void> _generateGameFrames() async {
    // If frames are pre-generated, use them directly
    if (widget.preGeneratedFrames != null &&
        widget.preGeneratedFrames!.isNotEmpty) {
      debugPrint(
        'Using pre-generated frames: ${widget.preGeneratedFrames!.length} frames',
      );
      setState(() {
        _gameFrames = widget.preGeneratedFrames!;
        _isGeneratingFrames = false;

        // Initialize frame manager for smooth playback
        _frameManager = VideoOverlayFrameManager(framePaths: _gameFrames);

        // Set context and preload after widget is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _frameManager != null) {
            _frameManager!.setContext(context);
            _frameManager!.preloadFrames(0);
          }
        });
      });
      return;
    }

    // Otherwise generate frames
    setState(() {
      _isGeneratingFrames = true;
      _generationError = null;
    });

    try {
      debugPrint('Starting frame generation for PiP overlay...');
      final frames = await GameReplayRenderer.generateGameReplayFrames(
        recordingResult: widget.recordingResult,
        deckColor: widget.deckColor,
        gameDuration: widget.recordingResult.duration,
      );

      debugPrint('Generated ${frames.length} frames for overlay');

      if (mounted) {
        setState(() {
          _gameFrames = frames;
          _isGeneratingFrames = false;

          // Initialize frame manager for smooth playback
          _frameManager = VideoOverlayFrameManager(framePaths: _gameFrames);

          // Set context and preload after widget is built
          if (_gameFrames.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _frameManager != null) {
                _frameManager!.setContext(context);
                _frameManager!.preloadFrames(0);
              }
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error generating game frames: $e');
      if (mounted) {
        setState(() {
          _isGeneratingFrames = false;
          _generationError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _frameManager?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Only clean up frame files if they were generated by this screen
    if (widget.preGeneratedFrames == null) {
      for (final frame in _gameFrames) {
        try {
          File(frame).deleteSync();
        } catch (e) {
          // Ignore errors
        }
      }
    }
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
    _hapticService.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player - full screen without cropping
          if (_isInitialized && _controller != null)
            Container(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),

          // PiP overlay
          if (_gameFrames.isNotEmpty && _isInitialized)
            Positioned(
              bottom: 100,
              right: 20,
              child: Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 50),
                        child:
                            _currentFrameIndex < _gameFrames.length
                                ? _frameManager?.getFrame(_currentFrameIndex) ??
                                    Image.file(
                                      File(_gameFrames[_currentFrameIndex]),
                                      key: ValueKey(_currentFrameIndex),
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Container(
                                          color: widget.deckColor.withOpacity(
                                            0.3,
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Colors.white54,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                : Container(
                                  key: const ValueKey('empty'),
                                  color: widget.deckColor.withOpacity(0.3),
                                  child: const Center(
                                    child: Text(
                                      'Game Replay',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                      ),

                      // Frame number debug (optional - remove in production)
                      // ignore: dead_code
                      if (false) // Set to true for debugging
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Frame ${_currentFrameIndex + 1}/${_gameFrames.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Processing indicator for overlay
          if (_isGeneratingFrames)
            Positioned(
              bottom: 100,
              right: 20,
              child: Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generating overlay...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      if (_generationError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Error: $_generationError',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Controls overlay
          if (_isInitialized)
            GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Header with back button and actions
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.save_alt_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _showSaveOptions,
                    tooltip: 'Save',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    onPressed: _showShareOptions,
                    tooltip: 'Share',
                  ),
                ],
              ),
            ),
          ),

          // Video controls
          if (_isInitialized && _controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: AppTheme.primaryColor,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Time display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_controller!.value.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(_controller!.value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showSaveOptions() {
    _controller?.pause();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Icon(
                  Icons.save_alt_rounded,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Save Video with Game Overlay',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'To save the complete video with game overlay:',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildInstructionStep('1', 'Start screen recording'),
                      const SizedBox(height: 12),
                      _buildInstructionStep(
                        '2',
                        'Play this video in full screen',
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionStep('3', 'Stop recording when done'),
                      const SizedBox(height: 12),
                      _buildInstructionStep('4', 'Save from your gallery'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          // Save reaction video only
                          final saved = await VideoUtils.saveVideoToGallery(
                            widget.videoPath,
                          );
                          if (saved && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Reaction video saved (without overlay)',
                                ),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Save Reaction Only'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _startScreenRecordingMode();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Start Recording'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _showShareOptions() {
    _controller?.pause();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Icon(
                  Icons.share_rounded,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Share Video',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose how to share your video:',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Share reaction video
                    await Share.shareXFiles([
                      XFile(widget.videoPath),
                    ], text: 'Check out my Heads Up! reaction! 🎮');
                  },
                  icon: const Icon(Icons.video_library),
                  label: const Text('Share Reaction Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Create composite video with native implementation
                    _createAndShareCompositeVideo();
                  },
                  icon: const Icon(Icons.layers),
                  label: const Text('Share with Game Overlay'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Future<void> _createAndShareCompositeVideo() async {
    // Show progress dialog
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
              ],
            ),
          ),
    );

    try {
      // Use pre-generated frames if available
      final framesToUse = widget.preGeneratedFrames ?? _gameFrames;

      // Call native video composer
      final result = await NativeVideoComposer.composeVideoWithOverlay(
        reactionVideoPath: widget.videoPath,
        recordingResult: widget.recordingResult,
        gameFrames: framesToUse,
        deckColor: widget.deckColor,
        onProgress: (progress) {
          // Progress is handled by native code
        },
      );

      Navigator.pop(context); // Close progress dialog

      if (result != null) {
        // Share the composite video
        await Share.shareXFiles([
          XFile(result),
        ], text: 'Check out my Heads Up! game with reactions! 🎮🎬');

        // Clean up temporary file
        try {
          await File(result).delete();
        } catch (e) {
          debugPrint('Error deleting temporary composite video: $e');
        }
      } else {
        throw Exception('Failed to create composite video');
      }
    } catch (e) {
      Navigator.pop(context); // Close progress dialog

      // Show error and fallback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to create overlay video. Try screen recording.',
            ),
            backgroundColor: AppTheme.warningColor,
          ),
        );

        // Fallback to screen recording mode
        _startScreenRecordingMode();
      }
    }
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  void _startScreenRecordingMode() {
    // Show screen recording instructions
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => ScreenRecorderOverlay(
              child: VideoPlayerWithOverlayScreen(
                videoPath: widget.videoPath,
                title: widget.title,
                recordingResult: widget.recordingResult,
                deckColor: widget.deckColor,
                preGeneratedFrames: widget.preGeneratedFrames,
              ),
              onRecordingComplete: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Video with overlay saved to gallery!'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              },
            ),
      ),
    );
  }
}
