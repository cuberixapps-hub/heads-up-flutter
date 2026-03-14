import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isSoundEnabled = true;

  final List<AudioPlayer> _countdownPlayers = [];
  String? _countdownAsset;
  int _countdownPlayIndex = 0;

  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  /// Pre-load 3 independent AudioPlayer instances (one per tick) so each
  /// playback is instant with zero asset-loading lag.
  Future<void> preloadCountdown() async {
    disposeCountdownPlayer();

    final soundOptions = ['sounds/countdown.wav', 'sounds/countdown.mp3'];
    for (final sound in soundOptions) {
      try {
        final testPlayer = AudioPlayer();
        await testPlayer.setSource(AssetSource(sound));
        testPlayer.dispose();
        _countdownAsset = sound;
        break;
      } catch (_) {}
    }
    if (_countdownAsset == null) return;

    for (int i = 0; i < 3; i++) {
      final p = AudioPlayer();
      await p.setSource(AssetSource(_countdownAsset!));
      _countdownPlayers.add(p);
    }
    _countdownPlayIndex = 0;
  }

  Future<void> playPreloadedCountdown() async {
    if (!_isSoundEnabled) return;
    if (_countdownPlayers.isNotEmpty &&
        _countdownPlayIndex < _countdownPlayers.length) {
      final p = _countdownPlayers[_countdownPlayIndex];
      _countdownPlayIndex++;
      await p.seek(Duration.zero);
      await p.resume();
    } else {
      await playCountdown();
    }
  }

  void disposeCountdownPlayer() {
    for (final p in _countdownPlayers) {
      p.dispose();
    }
    _countdownPlayers.clear();
    _countdownAsset = null;
    _countdownPlayIndex = 0;
  }

  Future<void> playCorrect() async {
    if (!_isSoundEnabled) return;

    // Try different file formats and names
    final soundOptions = [
      'sounds/ting.wav',
      'sounds/ting.mp3',
      'sounds/correct.wav',
      'sounds/correct.mp3',
    ];

    for (final sound in soundOptions) {
      try {
        await _player.play(AssetSource(sound));
        return; // If successful, exit
      } catch (e) {
        // Try next option
      }
    }
  }

  Future<void> playPass() async {
    if (!_isSoundEnabled) return;

    // Try different file formats and names
    final soundOptions = [
      'sounds/page_tear.wav',
      'sounds/page_tear.mp3',
      'sounds/pass.wav',
      'sounds/pass.mp3',
    ];

    for (final sound in soundOptions) {
      try {
        await _player.play(AssetSource(sound));
        return; // If successful, exit
      } catch (e) {
        // Try next option
      }
    }
  }

  Future<void> playCountdown() async {
    if (!_isSoundEnabled) return;
    final soundOptions = ['sounds/countdown.wav', 'sounds/countdown.mp3'];
    for (final sound in soundOptions) {
      try {
        await _player.play(AssetSource(sound));
        return;
      } catch (e) {
        // Try next option
      }
    }
  }

  Future<void> playTimeUp() async {
    if (!_isSoundEnabled) return;
    final soundOptions = ['sounds/time_up.wav', 'sounds/time_up.mp3'];
    for (final sound in soundOptions) {
      try {
        await _player.play(AssetSource(sound));
        return;
      } catch (e) {
        // Try next option
      }
    }
  }

  Future<void> playClick() async {
    if (!_isSoundEnabled) return;
    final soundOptions = ['sounds/click.wav', 'sounds/click.mp3'];
    for (final sound in soundOptions) {
      try {
        await _player.play(AssetSource(sound));
        return;
      } catch (e) {
        // Try next option
      }
    }
  }

  Future<void> playSuccess() async {
    if (!_isSoundEnabled) return;
    final soundOptions = ['sounds/success.wav', 'sounds/success.mp3'];
    for (final sound in soundOptions) {
      try {
        await _player.play(AssetSource(sound));
        return;
      } catch (e) {
        // Try next option
      }
    }
  }

  Future<void> playGameOver() async {
    if (!_isSoundEnabled) return;
    final soundOptions = [
      'sounds/gameover_sound.mp3',
      'sounds/gameover_sound.wav',
    ];
    for (final sound in soundOptions) {
      try {
        await _player.play(AssetSource(sound));
        return;
      } catch (e) {
        // Try next option
      }
    }
  }

  Future<void> playVictory() async {
    if (!_isSoundEnabled) return;
    final soundOptions = [
      'sounds/victory.wav',
      'sounds/victory.mp3',
      'sounds/success.wav', // Fallback to success sound
      'sounds/success.mp3',
    ];
    for (final sound in soundOptions) {
      try {
        await _player.play(AssetSource(sound));
        return;
      } catch (e) {
        // Try next option
      }
    }
  }

  void dispose() {
    _player.dispose();
  }
}
