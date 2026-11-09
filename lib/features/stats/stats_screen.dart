import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/session_record.dart';
import '../../data/repositories/session_repository.dart';
import '../../services/auth_service.dart';
import 'stats_calculator.dart';
import 'widgets/bar_chart_widget.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<List<SessionRecord>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 30));
      _statsFuture = context.read<SessionRepository>().getSessionsForDateRange(
            user.id,
            start: startDate,
            end: now,
          );
    } else {
      _statsFuture = Future.value([]);
    }
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.query_stats_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Aktivitas Fokus',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selesaikan sesi fokus untuk melihat ringkasan waktu belajar dan streak mingguanmu.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Fokus'),
      ),
      body: FutureBuilder<List<SessionRecord>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Gagal memuat statistik: ${snapshot.error}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }

          final sessions = snapshot.data ?? [];
          final stats = StatsCalculator.calculate(sessions);

          if (stats.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _loadStats();
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _buildMetricCard(
                        context: context,
                        title: 'Hari Ini',
                        value: stats.todayFocusMinutes.toString(),
                        unit: 'menit',
                        icon: Icons.today_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      _buildMetricCard(
                        context: context,
                        title: '7 Hari Ini',
                        value: stats.weekFocusMinutes.toString(),
                        unit: 'menit',
                        icon: Icons.date_range_outlined,
                        color: theme.colorScheme.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMetricCard(
                        context: context,
                        title: 'Streak Harian',
                        value: stats.currentStreakDays.toString(),
                        unit: 'hari',
                        icon: Icons.local_fire_department_outlined,
                        color: Colors.amberAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  BarChartWidget(dailyStats: stats.last7Days),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
