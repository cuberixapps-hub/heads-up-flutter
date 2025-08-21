import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isSoundEnabled = true;

  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  Future<void> playCorrect() async {
    if (!_isSoundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/correct.mp3'));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> playPass() async {
    if (!_isSoundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/pass.mp3'));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> playCountdown() async {
    if (!_isSoundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/countdown.mp3'));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> playTimeUp() async {
    if (!_isSoundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/time_up.mp3'));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> playClick() async {
    if (!_isSoundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/click.mp3'));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> playSuccess() async {
    if (!_isSoundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> playVictory() async {
    if (!_isSoundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/victory.mp3'));
    } catch (e) {
      // Handle error silently - fallback to success sound
      try {
        await _player.play(AssetSource('sounds/success.mp3'));
      } catch (e) {
        // Handle error silently
      }
    }
  }

  void dispose() {
    _player.dispose();
  }
}
