import '../../data/models/session_record.dart';

class DailyStat {
  final DateTime date;
  final String dayLabel;
  final int focusMinutes;
  final int sessionCount;

  const DailyStat({
    required this.date,
    required this.dayLabel,
    required this.focusMinutes,
    required this.sessionCount,
  });
}

class UserStats {
  final int todayFocusMinutes;
  final int weekFocusMinutes;
  final int currentStreakDays;
  final List<DailyStat> last7Days;

  const UserStats({
    required this.todayFocusMinutes,
    required this.weekFocusMinutes,
    required this.currentStreakDays,
    required this.last7Days,
  });

  bool get isEmpty =>
      todayFocusMinutes == 0 &&
      weekFocusMinutes == 0 &&
      last7Days.every((d) => d.sessionCount == 0);
}

class StatsCalculator {
  static const List<String> _dayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

  static UserStats calculate(List<SessionRecord> sessions, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final todayStart = DateTime(current.year, current.month, current.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final sevenDaysAgoStart = todayStart.subtract(const Duration(days: 6));

    final focusSessions = sessions.where((s) => s.mode == 'focus').toList();

    int todayMinutes = 0;
    int weekMinutes = 0;

    final Map<DateTime, List<SessionRecord>> sessionsByDay = {};

    for (final session in focusSessions) {
      final sessionDay = DateTime(
        session.createdAt.year,
        session.createdAt.month,
        session.createdAt.day,
      );

      sessionsByDay.putIfAbsent(sessionDay, () => []).add(session);

      if (session.createdAt.isAfter(todayStart) && session.createdAt.isBefore(todayEnd)) {
        todayMinutes += session.durationMinutes;
      }

      if (!session.createdAt.isBefore(sevenDaysAgoStart) &&
          session.createdAt.isBefore(todayEnd)) {
        weekMinutes += session.durationMinutes;
      }
    }

    final List<DailyStat> last7Days = [];
    for (int i = 0; i < 7; i++) {
      final date = sevenDaysAgoStart.add(Duration(days: i));
      final daySessions = sessionsByDay[date] ?? [];
      final minutes = daySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      final label = _dayNames[date.weekday % 7];

      last7Days.add(DailyStat(
        date: date,
        dayLabel: label,
        focusMinutes: minutes,
        sessionCount: daySessions.length,
      ));
    }

    final streak = _calculateStreak(sessionsByDay, todayStart);

    return UserStats(
      todayFocusMinutes: todayMinutes,
      weekFocusMinutes: weekMinutes,
      currentStreakDays: streak,
      last7Days: last7Days,
    );
  }

  static int _calculateStreak(
    Map<DateTime, List<SessionRecord>> sessionsByDay,
    DateTime todayStart,
  ) {
    int streak = 0;
    final hasToday = (sessionsByDay[todayStart]?.isNotEmpty ?? false);

    DateTime checkDate = hasToday ? todayStart : todayStart.subtract(const Duration(days: 1));

    while (true) {
      final hasSession = sessionsByDay[checkDate]?.isNotEmpty ?? false;
      if (hasSession) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }
}
