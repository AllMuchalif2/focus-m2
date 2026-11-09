import 'package:flutter_test/flutter_test.dart';
import 'package:focus/data/models/session_record.dart';
import 'package:focus/features/stats/stats_calculator.dart';

void main() {
  group('StatsCalculator Tests', () {
    final now = DateTime(2026, 3, 10, 14, 0);

    test('Calculates empty stats when no sessions exist', () {
      final stats = StatsCalculator.calculate([], now: now);

      expect(stats.isEmpty, isTrue);
      expect(stats.todayFocusMinutes, 0);
      expect(stats.weekFocusMinutes, 0);
      expect(stats.currentStreakDays, 0);
      expect(stats.last7Days.length, 7);
      expect(stats.last7Days.every((d) => d.focusMinutes == 0), isTrue);
    });

    test('Aggregates today and week focus minutes correctly', () {
      final sessions = [
        SessionRecord(
          id: '1',
          userId: 'u1',
          mode: 'focus',
          durationMinutes: 25,
          createdAt: DateTime(2026, 3, 10, 10, 0),
        ),
        SessionRecord(
          id: '2',
          userId: 'u1',
          mode: 'focus',
          durationMinutes: 25,
          createdAt: DateTime(2026, 3, 10, 11, 0),
        ),
        SessionRecord(
          id: '3',
          userId: 'u1',
          mode: 'shortBreak',
          durationMinutes: 5,
          createdAt: DateTime(2026, 3, 10, 10, 25),
        ),
        SessionRecord(
          id: '4',
          userId: 'u1',
          mode: 'focus',
          durationMinutes: 50,
          createdAt: DateTime(2026, 3, 8, 15, 0),
        ),
      ];

      final stats = StatsCalculator.calculate(sessions, now: now);

      expect(stats.isEmpty, isFalse);
      expect(stats.todayFocusMinutes, 50);
      expect(stats.weekFocusMinutes, 100);
      expect(stats.currentStreakDays, 1);
    });

    test('Calculates consecutive daily streak correctly', () {
      final sessions = [
        SessionRecord(
          id: '1',
          userId: 'u1',
          mode: 'focus',
          durationMinutes: 25,
          createdAt: DateTime(2026, 3, 10, 10, 0),
        ),
        SessionRecord(
          id: '2',
          userId: 'u1',
          mode: 'focus',
          durationMinutes: 25,
          createdAt: DateTime(2026, 3, 9, 10, 0),
        ),
        SessionRecord(
          id: '3',
          userId: 'u1',
          mode: 'focus',
          durationMinutes: 25,
          createdAt: DateTime(2026, 3, 8, 10, 0),
        ),
      ];

      final stats = StatsCalculator.calculate(sessions, now: now);

      expect(stats.currentStreakDays, 3);
    });
  });
}
