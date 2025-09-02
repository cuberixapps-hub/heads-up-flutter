import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class TestCameraScreen extends StatefulWidget {
  const TestCameraScreen({super.key});

  @override
  State<TestCameraScreen> createState() => _TestCameraScreenState();
}

class _TestCameraScreenState extends State<TestCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _status = 'Getting cameras...';
    });

    try {
      // Get cameras - this will trigger permission dialogs on iOS
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _status = 'No cameras found';
        });
        return;
      }

      // Find front camera
      CameraDescription? frontCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }
      frontCamera ??= cameras.first;

      setState(() {
        _status = 'Initializing camera...';
      });

      // Create controller
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
        _status = 'Camera ready';
      });
    } catch (e) {
      setState(() {
        if (e.toString().contains('Camera access') ||
            e.toString().contains('permission') ||
            e.toString().contains('authorized')) {
          _status = 'Camera permission denied. Please enable in Settings.';
        } else {
          _status = 'Error: $e';
        }
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized || _controller == null) return;

    if (_isRecording) {
      // Stop recording
      final file = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _status = 'Recording saved to: ${file.path}';
      });
    } else {
      // Start recording
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _status = 'Recording...';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Camera')),
      body: Column(
        children: [
          // Status
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Text(
              _status,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          // Camera preview
          Expanded(
            child:
                _isInitialized && _controller != null
                    ? CameraPreview(_controller!)
                    : const Center(child: CircularProgressIndicator()),
          ),
          // Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isInitialized ? _toggleRecording : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  ),
                  child: Text(
                    _isRecording ? 'Stop Recording' : 'Start Recording',
                  ),
                ),
                ElevatedButton(
                  onPressed: _initializeCamera,
                  child: const Text('Reinitialize'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
