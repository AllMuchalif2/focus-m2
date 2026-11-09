import 'package:flutter_test/flutter_test.dart';
import 'package:focus/services/timer_engine.dart';

void main() {
  group('TimerEngine Unit Tests', () {
    late TimerEngine engine;
    final baseTime = DateTime(2026, 1, 1, 10, 0, 0);

    setUp(() {
      engine = TimerEngine(
        mode: TimerMode.focus,
        customDuration: const Duration(minutes: 25),
      );
    });

    test('Initial state is correct', () {
      expect(engine.status, TimerStatus.initial);
      expect(engine.mode, TimerMode.focus);
      expect(engine.totalDuration, const Duration(minutes: 25));
      expect(engine.remainingDuration, const Duration(minutes: 25));
      expect(engine.startAt, isNull);
      expect(engine.endAt, isNull);
    });

    test('Start initializes endAt and sets running status', () {
      engine.start(now: baseTime);

      expect(engine.status, TimerStatus.running);
      expect(engine.startAt, baseTime);
      expect(engine.endAt, baseTime.add(const Duration(minutes: 25)));
      expect(engine.remainingDuration, const Duration(minutes: 25));
    });

    test('Tick updates remaining duration accurately without counting ticks', () {
      engine.start(now: baseTime);

      final tenMinutesLater = baseTime.add(const Duration(minutes: 10));
      final status = engine.tick(tenMinutesLater);

      expect(status, TimerStatus.running);
      expect(engine.remainingDuration, const Duration(minutes: 15));
    });

    test('Tick transitions to completed when time expires', () {
      engine.start(now: baseTime);

      final afterEnd = baseTime.add(const Duration(minutes: 25, seconds: 1));
      final status = engine.tick(afterEnd);

      expect(status, TimerStatus.completed);
      expect(engine.remainingDuration, Duration.zero);
      expect(engine.isCompleted, isTrue);
    });

    test('Pause preserves remaining duration and clears endAt', () {
      engine.start(now: baseTime);

      final tenMinutesLater = baseTime.add(const Duration(minutes: 10));
      engine.pause(now: tenMinutesLater);

      expect(engine.status, TimerStatus.paused);
      expect(engine.endAt, isNull);
      expect(engine.remainingDuration, const Duration(minutes: 15));
    });

    test('Resume recalculates endAt based on remaining duration', () {
      engine.start(now: baseTime);

      final tenMinutesLater = baseTime.add(const Duration(minutes: 10));
      engine.pause(now: tenMinutesLater);

      final resumeTime = baseTime.add(const Duration(minutes: 20));
      engine.resume(now: resumeTime);

      expect(engine.status, TimerStatus.running);
      expect(engine.endAt, resumeTime.add(const Duration(minutes: 15)));
      expect(engine.remainingDuration, const Duration(minutes: 15));
    });

    test('Jump Time reduces remaining time', () {
      engine.start(now: baseTime);
      engine.jumpTime(const Duration(minutes: 20));

      expect(engine.endAt, baseTime.add(const Duration(minutes: 5)));
    });

    test('Serialization and restoration to/from map works accurately', () {
      engine.start(now: baseTime);
      final map = engine.toMap();

      final restoredRunning = TimerEngine.fromMap(
        map,
        now: baseTime.add(const Duration(minutes: 5)),
      );
      expect(restoredRunning.status, TimerStatus.running);
      expect(restoredRunning.remainingDuration, const Duration(minutes: 20));

      final restoredExpired = TimerEngine.fromMap(
        map,
        now: baseTime.add(const Duration(minutes: 30)),
      );
      expect(restoredExpired.status, TimerStatus.completed);
      expect(restoredExpired.remainingDuration, Duration.zero);
    });

    test('Stop resets engine back to initial state', () {
      engine.start(now: baseTime);
      engine.stop();

      expect(engine.status, TimerStatus.initial);
      expect(engine.startAt, isNull);
      expect(engine.endAt, isNull);
      expect(engine.remainingDuration, const Duration(minutes: 25));
    });
  });
}
