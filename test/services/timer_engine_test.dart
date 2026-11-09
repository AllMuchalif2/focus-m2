import 'package:flutter_test/flutter_test.dart';
import 'package:focus/services/timer_engine.dart';

void main() {
  group('TimerEngine (Windows Style Single Session with Automatic Breaks)', () {
    late TimerEngine engine;
    final baseTime = DateTime(2026, 1, 1, 10, 0, 0);

    test('Default 30m session generates 25m focus and 5m break', () {
      engine = TimerEngine(totalMinutes: 30);

      expect(engine.status, TimerStatus.idle);
      expect(engine.totalSessionMinutes, 30);
      expect(engine.plans.length, 2);

      expect(engine.plans[0].phase, TimerPhase.focus);
      expect(engine.plans[0].duration, const Duration(minutes: 25));

      expect(engine.plans[1].phase, TimerPhase.shortBreak);
      expect(engine.plans[1].duration, const Duration(minutes: 5));
    });

    test('60m session generates 2 focus sessions (25m) and 2 break sessions (5m)', () {
      engine = TimerEngine(totalMinutes: 60);

      expect(engine.plans.length, 4);
      expect(engine.plans[0].phase, TimerPhase.focus);
      expect(engine.plans[0].duration, const Duration(minutes: 25));
      expect(engine.plans[1].phase, TimerPhase.shortBreak);
      expect(engine.plans[1].duration, const Duration(minutes: 5));

      expect(engine.plans[2].phase, TimerPhase.focus);
      expect(engine.plans[2].duration, const Duration(minutes: 25));
      expect(engine.plans[3].phase, TimerPhase.shortBreak);
      expect(engine.plans[3].duration, const Duration(minutes: 5));
    });

    test('Start begins phase 1 and endAt is based on phase duration', () {
      engine = TimerEngine(totalMinutes: 30);
      engine.start(baseTime);

      expect(engine.status, TimerStatus.running);
      expect(engine.currentPhase, TimerPhase.focus);
      expect(engine.endAt, baseTime.add(const Duration(minutes: 25)));
      expect(engine.calculateRemaining(baseTime.add(const Duration(minutes: 10))),
          const Duration(minutes: 15));
    });

    test('When 25m focus finishes, tick automatically transitions to 5m break', () {
      engine = TimerEngine(totalMinutes: 30);
      engine.start(baseTime);

      final focusEnd = baseTime.add(const Duration(minutes: 25));
      engine.tick(focusEnd);

      expect(engine.status, TimerStatus.running);
      expect(engine.currentPlanIndex, 1);
      expect(engine.currentPhase, TimerPhase.shortBreak);
      expect(engine.currentPhaseDuration, const Duration(minutes: 5));
      expect(engine.endAt, focusEnd.add(const Duration(minutes: 5)));
    });

    test('When 5m break finishes, session completes to finished status', () {
      engine = TimerEngine(totalMinutes: 30);
      engine.start(baseTime);

      // Finish focus
      final focusEnd = baseTime.add(const Duration(minutes: 25));
      engine.tick(focusEnd);

      // Finish break
      final breakEnd = focusEnd.add(const Duration(minutes: 5));
      engine.tick(breakEnd);

      expect(engine.status, TimerStatus.finished);
      expect(engine.isFinished, isTrue);
      expect(engine.endAt, isNull);
    });

    test('Pause and resume preserve accurate remaining time', () {
      engine = TimerEngine(totalMinutes: 30);
      engine.start(baseTime);

      final tenMinutesLater = baseTime.add(const Duration(minutes: 10));
      engine.pause(tenMinutesLater);

      expect(engine.status, TimerStatus.paused);
      expect(engine.calculateRemaining(tenMinutesLater), const Duration(minutes: 15));

      final resumeTime = baseTime.add(const Duration(minutes: 20));
      engine.resume(resumeTime);

      expect(engine.status, TimerStatus.running);
      expect(engine.endAt, resumeTime.add(const Duration(minutes: 15)));
    });

    test('Stop resets engine back to idle and initial phase', () {
      engine = TimerEngine(totalMinutes: 30);
      engine.start(baseTime);
      engine.stop();

      expect(engine.status, TimerStatus.idle);
      expect(engine.currentPlanIndex, 0);
      expect(engine.currentPhase, TimerPhase.focus);
      expect(engine.startAt, isNull);
      expect(engine.endAt, isNull);
    });
  });
}
