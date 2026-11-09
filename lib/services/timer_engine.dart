enum TimerStatus {
  initial,
  running,
  paused,
  completed,
}

enum TimerMode {
  focus,
  shortBreak,
  longBreak,
}

extension TimerModeExtension on TimerMode {
  Duration get defaultDuration {
    switch (this) {
      case TimerMode.focus:
        return const Duration(minutes: 25);
      case TimerMode.shortBreak:
        return const Duration(minutes: 5);
      case TimerMode.longBreak:
        return const Duration(minutes: 15);
    }
  }

  String get displayName {
    switch (this) {
      case TimerMode.focus:
        return 'Fokus';
      case TimerMode.shortBreak:
        return 'Istirahat Singkat';
      case TimerMode.longBreak:
        return 'Istirahat Panjang';
    }
  }
}

class TimerEngine {
  TimerStatus _status;
  TimerMode _mode;
  Duration _totalDuration;
  Duration _remainingDuration;
  DateTime? _startAt;
  DateTime? _endAt;

  TimerEngine({
    TimerMode mode = TimerMode.focus,
    Duration? customDuration,
  })  : _mode = mode,
        _status = TimerStatus.initial,
        _totalDuration = customDuration ?? mode.defaultDuration,
        _remainingDuration = customDuration ?? mode.defaultDuration;

  TimerStatus get status => _status;
  TimerMode get mode => _mode;
  Duration get totalDuration => _totalDuration;
  Duration get remainingDuration => _remainingDuration;
  DateTime? get startAt => _startAt;
  DateTime? get endAt => _endAt;

  bool get isRunning => _status == TimerStatus.running;
  bool get isPaused => _status == TimerStatus.paused;
  bool get isCompleted => _status == TimerStatus.completed;
  bool get isInitial => _status == TimerStatus.initial;

  void setMode(TimerMode mode, {Duration? customDuration}) {
    if (_status == TimerStatus.running) {
      stop();
    }
    _mode = mode;
    _totalDuration = customDuration ?? mode.defaultDuration;
    _remainingDuration = _totalDuration;
    _status = TimerStatus.initial;
    _startAt = null;
    _endAt = null;
  }

  void start({DateTime? now, TimerMode? mode, Duration? duration}) {
    final currentTime = now ?? DateTime.now();
    if (mode != null) {
      _mode = mode;
    }
    if (duration != null) {
      _totalDuration = duration;
    }

    _startAt = currentTime;
    _remainingDuration = _totalDuration;
    _endAt = currentTime.add(_totalDuration);
    _status = TimerStatus.running;
  }

  void pause({DateTime? now}) {
    if (_status != TimerStatus.running) return;

    final currentTime = now ?? DateTime.now();
    _remainingDuration = _calculateRemaining(currentTime);
    _endAt = null;
    _status = TimerStatus.paused;
  }

  void resume({DateTime? now}) {
    if (_status != TimerStatus.paused) return;

    final currentTime = now ?? DateTime.now();
    _endAt = currentTime.add(_remainingDuration);
    _status = TimerStatus.running;
  }

  void stop() {
    _status = TimerStatus.initial;
    _remainingDuration = _totalDuration;
    _startAt = null;
    _endAt = null;
  }

  TimerStatus tick(DateTime now) {
    if (_status != TimerStatus.running) {
      return _status;
    }

    if (_endAt == null) {
      _status = TimerStatus.paused;
      return _status;
    }

    if (!now.isBefore(_endAt!)) {
      _remainingDuration = Duration.zero;
      _status = TimerStatus.completed;
      return _status;
    }

    _remainingDuration = _calculateRemaining(now);
    return _status;
  }

  void jumpTime(Duration offset) {
    if (_status != TimerStatus.running || _endAt == null) return;
    _endAt = _endAt!.subtract(offset);
    tick(DateTime.now());
  }

  Duration _calculateRemaining(DateTime now) {
    if (_endAt == null) {
      return _remainingDuration;
    }
    final difference = _endAt!.difference(now);
    return difference.isNegative ? Duration.zero : difference;
  }

  Map<String, dynamic> toMap() {
    return {
      'status': _status.name,
      'mode': _mode.name,
      'totalDurationMs': _totalDuration.inMilliseconds,
      'remainingDurationMs': _remainingDuration.inMilliseconds,
      'startAt': _startAt?.toIso8601String(),
      'endAt': _endAt?.toIso8601String(),
    };
  }

  factory TimerEngine.fromMap(Map<String, dynamic> map, {DateTime? now}) {
    final mode = TimerMode.values.firstWhere(
      (m) => m.name == map['mode'],
      orElse: () => TimerMode.focus,
    );
    final totalDuration = Duration(
      milliseconds: map['totalDurationMs'] as int? ?? mode.defaultDuration.inMilliseconds,
    );
    final remainingDuration = Duration(
      milliseconds: map['remainingDurationMs'] as int? ?? totalDuration.inMilliseconds,
    );
    final statusStr = map['status'] as String? ?? TimerStatus.initial.name;
    final savedStatus = TimerStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => TimerStatus.initial,
    );

    final startAt = map['startAt'] != null ? DateTime.parse(map['startAt'] as String) : null;
    final endAt = map['endAt'] != null ? DateTime.parse(map['endAt'] as String) : null;

    final engine = TimerEngine(mode: mode, customDuration: totalDuration)
      .._startAt = startAt
      .._endAt = endAt
      .._remainingDuration = remainingDuration
      .._status = savedStatus;

    if (savedStatus == TimerStatus.running && endAt != null) {
      final currentTime = now ?? DateTime.now();
      if (!currentTime.isBefore(endAt)) {
        engine._status = TimerStatus.completed;
        engine._remainingDuration = Duration.zero;
      } else {
        engine._remainingDuration = endAt.difference(currentTime);
      }
    }

    return engine;
  }
}
