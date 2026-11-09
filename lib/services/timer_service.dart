import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'notification_service.dart';
import 'timer_engine.dart';

class TimerService extends ChangeNotifier {
  static const String _prefKey = 'active_timer_state';

  final TimerEngine _engine;
  final NotificationService _notificationService;
  Timer? _ticker;
  bool _isRestored = false;

  TimerService({
    TimerEngine? engine,
    NotificationService? notificationService,
  })  : _engine = engine ?? TimerEngine(),
        _notificationService = notificationService ?? NotificationService();

  TimerStatus get status => _engine.status;
  TimerMode get mode => _engine.mode;
  Duration get totalDuration => _engine.totalDuration;
  Duration get remainingDuration => _engine.remainingDuration;
  DateTime? get startAt => _engine.startAt;
  DateTime? get endAt => _engine.endAt;

  bool get isRunning => _engine.isRunning;
  bool get isPaused => _engine.isPaused;
  bool get isCompleted => _engine.isCompleted;
  bool get isInitial => _engine.isInitial;
  bool get isRestored => _isRestored;

  double get progress {
    if (_engine.totalDuration.inMilliseconds == 0) return 0.0;
    final value = 1.0 -
        (_engine.remainingDuration.inMilliseconds /
            _engine.totalDuration.inMilliseconds);
    return value.clamp(0.0, 1.0);
  }

  String get formattedRemaining {
    final minutes = _engine.remainingDuration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _engine.remainingDuration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> initialize() async {
    await _notificationService.initialize();
    await _restoreState();
    _isRestored = true;
    notifyListeners();
  }

  Future<void> setMode(TimerMode mode, {Duration? customDuration}) async {
    _stopTicker();
    await _updateWakelock(false);
    await _notificationService.cancelTimerNotification();

    _engine.setMode(mode, customDuration: customDuration);
    await _saveState();
    notifyListeners();
  }

  Future<void> start({TimerMode? mode, Duration? duration}) async {
    _engine.start(now: DateTime.now(), mode: mode, duration: duration);
    _startTicker();
    await _updateWakelock(true);

    if (_engine.endAt != null) {
      await _notificationService.scheduleTimerNotification(
        endAt: _engine.endAt!,
        title: 'Sesi Selesai',
        body: 'Sesi ${_engine.mode.displayName} telah berakhir.',
      );
    }

    await _saveState();
    notifyListeners();
  }

  Future<void> pause() async {
    _engine.pause(now: DateTime.now());
    _stopTicker();
    await _updateWakelock(false);
    await _notificationService.cancelTimerNotification();
    await _saveState();
    notifyListeners();
  }

  Future<void> resume() async {
    _engine.resume(now: DateTime.now());
    _startTicker();
    await _updateWakelock(true);

    if (_engine.endAt != null) {
      await _notificationService.scheduleTimerNotification(
        endAt: _engine.endAt!,
        title: 'Sesi Selesai',
        body: 'Sesi ${_engine.mode.displayName} telah berakhir.',
      );
    }

    await _saveState();
    notifyListeners();
  }

  Future<void> stop() async {
    _stopTicker();
    await _updateWakelock(false);
    await _notificationService.cancelTimerNotification();
    _engine.stop();
    await _clearState();
    notifyListeners();
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final oldStatus = _engine.status;
      final newStatus = _engine.tick(DateTime.now());

      if (newStatus == TimerStatus.completed && oldStatus != TimerStatus.completed) {
        _onCompleted();
      } else {
        notifyListeners();
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _onCompleted() async {
    _stopTicker();
    await _updateWakelock(false);
    await _notificationService.cancelTimerNotification();
    await _saveState();
    notifyListeners();
  }

  Future<void> _updateWakelock(bool enable) async {
    try {
      if (enable) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _engine.toMap();
      await prefs.setString(_prefKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _clearState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
  }

  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKey);
      if (jsonStr == null) return;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restoredEngine = TimerEngine.fromMap(map, now: DateTime.now());

      _engine.setMode(restoredEngine.mode, customDuration: restoredEngine.totalDuration);
      if (restoredEngine.status == TimerStatus.running) {
        _engine.start(
          now: restoredEngine.startAt,
          mode: restoredEngine.mode,
          duration: restoredEngine.totalDuration,
        );
        _engine.tick(DateTime.now());
        if (_engine.isRunning) {
          _startTicker();
          await _updateWakelock(true);
        } else if (_engine.isCompleted) {
          await _updateWakelock(false);
          await _notificationService.cancelTimerNotification();
        }
      } else if (restoredEngine.status == TimerStatus.paused) {
        _engine.start(
          now: restoredEngine.startAt,
          mode: restoredEngine.mode,
          duration: restoredEngine.totalDuration,
        );
        _engine.pause();
      } else if (restoredEngine.status == TimerStatus.completed) {
        _engine.start(
          now: restoredEngine.startAt,
          mode: restoredEngine.mode,
          duration: restoredEngine.totalDuration,
        );
        _engine.tick(restoredEngine.endAt ?? DateTime.now());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopTicker();
    _updateWakelock(false);
    super.dispose();
  }
}
