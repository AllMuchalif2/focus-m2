import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../core/constants.dart';

class MediaService extends ChangeNotifier {
  final AudioPlayer _ambiencePlayer;
  final AudioPlayer _alarmPlayer;
  VideoPlayerController? _videoController;

  String? _currentAmbienceUrl;
  String? _currentVideoUrl;
  double _ambienceVolume = 0.7;
  bool _isVideoInitialized = false;

  MediaService({
    AudioPlayer? ambiencePlayer,
    AudioPlayer? alarmPlayer,
  })  : _ambiencePlayer = ambiencePlayer ?? AudioPlayer(),
        _alarmPlayer = alarmPlayer ?? AudioPlayer();

  AudioPlayer get ambiencePlayer => _ambiencePlayer;
  AudioPlayer get alarmPlayer => _alarmPlayer;
  VideoPlayerController? get videoController => _videoController;

  String? get currentAmbienceUrl => _currentAmbienceUrl;
  String? get currentVideoUrl => _currentVideoUrl;
  double get ambienceVolume => _ambienceVolume;
  bool get isVideoInitialized => _isVideoInitialized;
  bool get isAmbiencePlaying => _ambiencePlayer.playing;

  Future<void> playAmbience(String url) async {
    try {
      if (_currentAmbienceUrl == url && _ambiencePlayer.playing) return;

      _currentAmbienceUrl = url;
      await _ambiencePlayer.setUrl(url);
      await _ambiencePlayer.setLoopMode(LoopMode.one);
      await _ambiencePlayer.setVolume(_ambienceVolume);
      await _ambiencePlayer.play();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> pauseAmbience() async {
    try {
      await _ambiencePlayer.pause();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> stopAmbience() async {
    try {
      _currentAmbienceUrl = null;
      await _ambiencePlayer.stop();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setAmbienceVolume(double volume) async {
    _ambienceVolume = volume.clamp(0.0, 1.0);
    await _ambiencePlayer.setVolume(_ambienceVolume);
    notifyListeners();
  }

  Future<void> playAlarm({String? url}) async {
    try {
      final alarmUrl = url ?? AppConstants.audioAlarm;
      final previousVolume = _ambienceVolume;

      await _ambiencePlayer.setVolume(previousVolume * 0.2);

      await _alarmPlayer.setUrl(alarmUrl);
      await _alarmPlayer.setLoopMode(LoopMode.off);
      await _alarmPlayer.setVolume(1.0);
      await _alarmPlayer.play();

      _alarmPlayer.playerStateStream
          .firstWhere((state) => state.processingState == ProcessingState.completed)
          .then((_) async {
        await _ambiencePlayer.setVolume(previousVolume);
      });
    } catch (_) {}
  }

  Future<void> stopAlarm() async {
    try {
      await _alarmPlayer.stop();
      await _ambiencePlayer.setVolume(_ambienceVolume);
    } catch (_) {}
  }

  Future<void> setVideoBackground(String? url) async {
    if (_currentVideoUrl == url && _videoController != null) return;

    if (_videoController != null) {
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
      _isVideoInitialized = false;
    }

    _currentVideoUrl = url;
    notifyListeners();

    if (url != null && url.isNotEmpty) {
      try {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        _videoController = controller;
        await controller.initialize();
        await controller.setVolume(0.0);
        await controller.setLooping(true);
        await controller.play();
        _isVideoInitialized = true;
      } catch (_) {
        _videoController = null;
        _isVideoInitialized = false;
      }
    }

    notifyListeners();
  }

  Future<void> pauseVideo() async {
    if (_videoController != null && _isVideoInitialized) {
      await _videoController!.pause();
      notifyListeners();
    }
  }

  Future<void> playVideo() async {
    if (_videoController != null && _isVideoInitialized) {
      await _videoController!.play();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ambiencePlayer.dispose();
    _alarmPlayer.dispose();
    _videoController?.dispose();
    super.dispose();
  }
}
