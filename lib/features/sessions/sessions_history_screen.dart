import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/session_record.dart';
import '../../data/repositories/session_repository.dart';
import '../../services/auth_service.dart';
import 'session_detail_screen.dart';

class SessionsHistoryScreen extends StatelessWidget {
  const SessionsHistoryScreen({super.key});

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Pengguna belum login')),
      );
    }

    final sessionRepo = context.watch<SessionRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Sesi'),
      ),
      body: StreamBuilder<List<SessionRecord>>(
        stream: sessionRepo.watchRecentSessions(user.id, limit: 10),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Terjadi kesalahan memuat data: ${snapshot.error}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_toggle_off_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada sesi tersimpan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selesaikan sesi fokus untuk melihat riwayat di sini.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isFocus = session.mode == 'focus';

              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isFocus
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.secondary.withValues(alpha: 0.15),
                    child: Icon(
                      isFocus ? Icons.psychology_outlined : Icons.coffee_outlined,
                      color: isFocus ? theme.colorScheme.primary : theme.colorScheme.secondary,
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isFocus ? 'Fokus' : 'Istirahat',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${session.durationMinutes} menit',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(session.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (session.reflection.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          session.reflection,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(session: session),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
