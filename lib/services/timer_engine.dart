enum TimerStatus { idle, running, paused, finished }

enum TimerPhase { focus, shortBreak, longBreak }

extension TimerPhaseExtension on TimerPhase {
  String get displayName {
    switch (this) {
      case TimerPhase.focus:
        return 'Fokus';
      case TimerPhase.shortBreak:
      case TimerPhase.longBreak:
        return 'Istirahat';
    }
  }

  bool get isFocus => this == TimerPhase.focus;
  bool get isBreak => this != TimerPhase.focus;
}

class PhasePlan {
  final TimerPhase phase;
  final Duration duration;

  const PhasePlan({required this.phase, required this.duration});

  Map<String, dynamic> toMap() {
    return {'phase': phase.name, 'durationMs': duration.inMilliseconds};
  }

  factory PhasePlan.fromMap(Map<String, dynamic> map) {
    final phaseName = map['phase'] as String? ?? TimerPhase.focus.name;
    final phase = TimerPhase.values.firstWhere(
      (p) => p.name == phaseName,
      orElse: () => TimerPhase.focus,
    );
    final durationMs = map['durationMs'] as int? ?? 25 * 60 * 1000;
    return PhasePlan(
      phase: phase,
      duration: Duration(milliseconds: durationMs),
    );
  }
}

class TimerEngine {
  TimerStatus _status;
  int _totalSessionMinutes;
  List<PhasePlan> _plans;
  int _currentPlanIndex;

  Duration _pausedRemaining;
  DateTime? _startAt;
  DateTime? _endAt;

  TimerEngine({int totalMinutes = 30})
    : _status = TimerStatus.idle,
      _totalSessionMinutes = totalMinutes < 1 ? 1 : totalMinutes,
      _plans = _generatePlans(totalMinutes < 1 ? 1 : totalMinutes),
      _currentPlanIndex = 0,
      _pausedRemaining = Duration.zero {
    _pausedRemaining = currentPhaseDuration;
  }

  TimerStatus get status => _status;
  int get totalSessionMinutes => _totalSessionMinutes;
  List<PhasePlan> get plans => List.unmodifiable(_plans);
  int get currentPlanIndex => _currentPlanIndex;
  int get totalPlansCount => _plans.length;

  TimerPhase get currentPhase =>
      _plans.isNotEmpty ? _plans[_currentPlanIndex].phase : TimerPhase.focus;
  TimerPhase get phase => currentPhase;

  DateTime? get startAt => _startAt;
  DateTime? get endAt => _endAt;

  Duration get currentPhaseDuration => _plans.isNotEmpty
      ? _plans[_currentPlanIndex].duration
      : const Duration(minutes: 25);

  Duration get remainingDuration {
    if (_status == TimerStatus.idle) {
      return currentPhaseDuration;
    }
    if (_status == TimerStatus.paused) {
      return _pausedRemaining;
    }
    if (_status == TimerStatus.finished) {
      return Duration.zero;
    }
    if (_endAt == null) {
      return currentPhaseDuration;
    }

    final now = DateTime.now();
    if (!now.isBefore(_endAt!)) {
      return Duration.zero;
    }
    return _endAt!.difference(now);
  }

  bool get isIdle => _status == TimerStatus.idle;
  bool get isRunning => _status == TimerStatus.running;
  bool get isPaused => _status == TimerStatus.paused;
  bool get isFinished => _status == TimerStatus.finished;

  static List<PhasePlan> _generatePlans(int totalMinutes) {
    final clamped = totalMinutes < 1 ? 1 : totalMinutes;
    final List<PhasePlan> result = [];
    int remaining = clamped;
    int focusCount = 0;

    while (remaining > 0) {
      if (remaining <= 25) {
        result.add(
          PhasePlan(
            phase: TimerPhase.focus,
            duration: Duration(minutes: remaining),
          ),
        );
        remaining = 0;
      } else if (remaining <= 30) {
        result.add(
          const PhasePlan(
            phase: TimerPhase.focus,
            duration: Duration(minutes: 25),
          ),
        );
        focusCount++;
        final breakMinutes = remaining - 25;
        if (breakMinutes > 0) {
          result.add(
            PhasePlan(
              phase: focusCount % 4 == 0
                  ? TimerPhase.longBreak
                  : TimerPhase.shortBreak,
              duration: Duration(minutes: breakMinutes),
            ),
          );
        }
        remaining = 0;
      } else {
        result.add(
          const PhasePlan(
            phase: TimerPhase.focus,
            duration: Duration(minutes: 25),
          ),
        );
        focusCount++;
        final isLong = focusCount % 4 == 0;
        result.add(
          PhasePlan(
            phase: isLong ? TimerPhase.longBreak : TimerPhase.shortBreak,
            duration: const Duration(minutes: 5),
          ),
        );
        remaining -= 30;
      }
    }

    return result;
  }

  void setTotalMinutes(int totalMinutes) {
    if (_status == TimerStatus.running) {
      stop();
    }
    _totalSessionMinutes = totalMinutes < 1 ? 1 : totalMinutes;
    _plans = _generatePlans(_totalSessionMinutes);
    _currentPlanIndex = 0;
    _pausedRemaining = currentPhaseDuration;
    _status = TimerStatus.idle;
    _startAt = null;
    _endAt = null;
  }

  void start([DateTime? now]) {
    final currentTime = now ?? DateTime.now();
    _startAt = currentTime;
    _endAt = currentTime.add(currentPhaseDuration);
    _status = TimerStatus.running;
  }

  void pause([DateTime? now]) {
    if (_status != TimerStatus.running) return;

    final currentTime = now ?? DateTime.now();
    if (_endAt != null && _endAt!.isAfter(currentTime)) {
      _pausedRemaining = _endAt!.difference(currentTime);
    } else {
      _pausedRemaining = Duration.zero;
    }

    _endAt = null;
    _status = TimerStatus.paused;
  }

  void resume([DateTime? now]) {
    if (_status != TimerStatus.paused) return;

    final currentTime = now ?? DateTime.now();
    _startAt = currentTime;
    _endAt = currentTime.add(_pausedRemaining);
    _status = TimerStatus.running;
  }

  void stop() {
    _status = TimerStatus.idle;
    _currentPlanIndex = 0;
    _startAt = null;
    _endAt = null;
    _pausedRemaining = currentPhaseDuration;
  }

  void finish() {
    _status = TimerStatus.finished;
    _endAt = null;
  }

  TimerStatus tick([DateTime? currentTime]) {
    if (_status != TimerStatus.running || _endAt == null) {
      return _status;
    }

    final now = currentTime ?? DateTime.now();
    while (_status == TimerStatus.running &&
        _endAt != null &&
        !now.isBefore(_endAt!)) {
      if (_currentPlanIndex < _plans.length - 1) {
        _currentPlanIndex++;
        _startAt = _endAt;
        _endAt = _endAt!.add(currentPhaseDuration);
      } else {
        _status = TimerStatus.finished;
        _endAt = null;
      }
    }

    return _status;
  }

  Duration calculateRemaining(DateTime now) {
    if (_status == TimerStatus.idle) {
      return currentPhaseDuration;
    }
    if (_status == TimerStatus.paused) {
      return _pausedRemaining;
    }
    if (_status == TimerStatus.finished) {
      return Duration.zero;
    }
    if (_endAt == null) {
      return currentPhaseDuration;
    }
    if (!now.isBefore(_endAt!)) {
      return Duration.zero;
    }
    return _endAt!.difference(now);
  }

  Map<String, dynamic> toMap() {
    return {
      'status': _status.name,
      'totalSessionMinutes': _totalSessionMinutes,
      'currentPlanIndex': _currentPlanIndex,
      'plans': _plans.map((p) => p.toMap()).toList(),
      'pausedRemainingMs': _pausedRemaining.inMilliseconds,
      'startAt': _startAt?.toIso8601String(),
      'endAt': _endAt?.toIso8601String(),
    };
  }

  factory TimerEngine.fromMap(Map<String, dynamic> map, {DateTime? now}) {
    final statusStr = map['status'] as String? ?? TimerStatus.idle.name;
    final savedStatus = TimerStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => TimerStatus.idle,
    );

    final totalMinutes = map['totalSessionMinutes'] as int? ?? 30;
    final planIndex = map['currentPlanIndex'] as int? ?? 0;
    final pausedMs = map['pausedRemainingMs'] as int?;
    final startAt = map['startAt'] != null
        ? DateTime.parse(map['startAt'] as String)
        : null;
    final endAt = map['endAt'] != null
        ? DateTime.parse(map['endAt'] as String)
        : null;

    final engine = TimerEngine(totalMinutes: totalMinutes)
      .._status = savedStatus
      .._currentPlanIndex = planIndex
      .._startAt = startAt
      .._endAt = endAt;

    if (pausedMs != null) {
      engine._pausedRemaining = Duration(milliseconds: pausedMs);
    }

    if (savedStatus == TimerStatus.running && endAt != null) {
      final currentTime = now ?? DateTime.now();
      if (!currentTime.isBefore(endAt)) {
        engine.tick(currentTime);
      }
    }

    return engine;
  }
}
