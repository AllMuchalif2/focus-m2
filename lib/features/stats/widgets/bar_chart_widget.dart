import 'dart:math';
import 'package:flutter/material.dart';
import '../stats_calculator.dart';

class BarChartWidget extends StatelessWidget {
  final List<DailyStat> dailyStats;

  const BarChartWidget({
    super.key,
    required this.dailyStats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMinutes = dailyStats.map((d) => d.focusMinutes).fold<int>(0, max);
    final chartMax = max(maxMinutes, 60);

    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aktivitas 7 Hari Terakhir',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Maks: ${chartMax}m',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 180,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: dailyStats.map((stat) {
              final isToday = stat.date.year == today.year &&
                  stat.date.month == today.month &&
                  stat.date.day == today.day;

              final ratio = (stat.focusMinutes / chartMax).clamp(0.0, 1.0);
              final barHeight = max(ratio * 110, 4.0);

              final barColor = isToday
                  ? theme.colorScheme.primary
                  : (stat.focusMinutes > 0
                      ? theme.colorScheme.secondary.withValues(alpha: 0.8)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.15));

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    stat.focusMinutes > 0 ? '${stat.focusMinutes}m' : '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 22,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stat.dayLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
