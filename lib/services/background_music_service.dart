import 'package:just_audio/just_audio.dart';

class BackgroundMusicService {
  BackgroundMusicService._();

  static final BackgroundMusicService instance = BackgroundMusicService._();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  bool _enabled = true;

  Future<void> play() async {
    if (!_enabled) return;
    if (!_initialized) {
      await _player.setLoopMode(LoopMode.all);
      await _player.setAsset('assets/sons/musique.mp3');
      _initialized = true;
    }
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _enabled ? _player.play() : Future.value();

  Future<void> stop() async {
    await _player.stop();
    _initialized = false;
  }

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    if (_enabled) {
      play();
    } else {
      _player.pause();
    }
  }
}
