import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'media_service.dart';
import 'notification_service.dart';
import 'timer_engine.dart';

class TimerService extends ChangeNotifier {
  static const String _prefKey = 'active_timer_state';

  final TimerEngine _engine;
  final NotificationService _notificationService;
  MediaService? _mediaService;
  Timer? _ticker;

  TimerService({
    TimerEngine? engine,
    NotificationService? notificationService,
    MediaService? mediaService,
  })  : _engine = engine ?? TimerEngine(totalMinutes: 30),
        _notificationService = notificationService ?? NotificationService(),
        _mediaService = mediaService;

  void attachMediaService(MediaService mediaService) {
    _mediaService = mediaService;
  }

  TimerStatus get status => _engine.status;
  TimerPhase get phase => _engine.phase;
  int get totalSessionMinutes => _engine.totalSessionMinutes;
  int get currentPlanIndex => _engine.currentPlanIndex;
  int get totalPlansCount => _engine.totalPlansCount;

  Duration get remainingDuration => _engine.remainingDuration;
  DateTime? get startAt => _engine.startAt;
  DateTime? get endAt => _engine.endAt;

  bool get isRunning => _engine.isRunning;
  bool get isPaused => _engine.isPaused;
  bool get isCompleted => _engine.isFinished;
  bool get isInitial => _engine.isIdle;
  bool get isIdle => _engine.isIdle;

  double get progress {
    if (_engine.currentPhaseDuration.inMilliseconds == 0) return 0.0;
    final value = 1.0 -
        (_engine.remainingDuration.inMilliseconds /
            _engine.currentPhaseDuration.inMilliseconds);
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
    notifyListeners();
  }

  Future<void> setTotalMinutes(int minutes) async {
    _stopTicker();
    await _updateWakelock(false);
    await _notificationService.cancelTimerNotification();

    _engine.setTotalMinutes(minutes);
    await _saveState();
    notifyListeners();
  }

  Future<void> _scheduleAllPhaseNotifications() async {
    await _notificationService.cancelTimerNotification();
    if (_engine.startAt == null) return;

    DateTime phaseStart = _engine.startAt!;
    for (int i = 0; i < _engine.plans.length; i++) {
      final plan = _engine.plans[i];
      final phaseEnd = phaseStart.add(plan.duration);
      final isLast = i == _engine.plans.length - 1;

      final title = isLast
          ? 'Sesi Selesai!'
          : (plan.phase.isFocus ? 'Sesi Fokus Selesai!' : 'Waktu Istirahat Selesai!');
      final body = isLast
          ? 'Seluruh sesi fokus telah selesai. Bagus sekali!'
          : (plan.phase.isFocus
              ? 'Waktunya istirahat.'
              : 'Mari mulai fokus kembali.');

      await _notificationService.scheduleTimerNotification(
        endAt: phaseEnd,
        title: title,
        body: body,
        id: 1000 + i,
      );

      phaseStart = phaseEnd;
    }
  }

  Future<void> start() async {
    _engine.start(DateTime.now());
    _startTicker();
    await _updateWakelock(true);
    await _scheduleAllPhaseNotifications();
    await _saveState();
    notifyListeners();
  }

  Future<void> pause() async {
    _engine.pause(DateTime.now());
    _stopTicker();
    await _updateWakelock(false);
    await _notificationService.cancelAllNotifications();
    await _saveState();
    notifyListeners();
  }

  Future<void> resume() async {
    _engine.resume(DateTime.now());
    _startTicker();
    await _updateWakelock(true);
    await _scheduleAllPhaseNotifications();
    await _saveState();
    notifyListeners();
  }

  Future<void> stop() async {
    _stopTicker();
    await _updateWakelock(false);
    await _notificationService.cancelAllNotifications();
    _engine.stop();
    await _clearState();
    notifyListeners();
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final oldPlanIndex = _engine.currentPlanIndex;
      final oldStatus = _engine.status;
      final newStatus = _engine.tick(DateTime.now());

      if (newStatus == TimerStatus.finished && oldStatus != TimerStatus.finished) {
        _onCompleted();
      } else if (_engine.currentPlanIndex != oldPlanIndex) {
        _onPhaseTransitioned();
      } else {
        notifyListeners();
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _onPhaseTransitioned() async {
    notifyListeners();
    try {
      await _mediaService?.playAlarm();
    } catch (_) {}
    await _saveState();
  }

  Future<void> _onCompleted() async {
    _stopTicker();
    notifyListeners();
    try {
      await _mediaService?.playAlarm();
    } catch (_) {}
    await _updateWakelock(false);
    await _saveState();
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
      final restored = TimerEngine.fromMap(map, now: DateTime.now());

      _engine.setTotalMinutes(restored.totalSessionMinutes);
      if (restored.status == TimerStatus.running) {
        _engine.start(restored.startAt);
        _engine.tick(DateTime.now());
        if (_engine.isRunning) {
          _startTicker();
          await _updateWakelock(true);
        }
      } else if (restored.status == TimerStatus.paused) {
        _engine.start(restored.startAt);
        _engine.pause();
      } else if (restored.status == TimerStatus.finished) {
        _engine.finish();
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
