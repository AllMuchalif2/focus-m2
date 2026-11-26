import 'package:flutter/material.dart';

import '../../../services/timer_engine.dart';

class TimerCircle extends StatelessWidget {
  final String formattedTime;
  final double progress;
  final TimerPhase mode;
  final TimerStatus status;

  const TimerCircle({
    super.key,
    required this.formattedTime,
    required this.progress,
    required this.mode,
    required this.status,
  });

  String get _statusLabel {
    switch (status) {
      case TimerStatus.running:
        return 'Sedang Berjalan';
      case TimerStatus.paused:
        return 'Dijeda';
      case TimerStatus.finished:
        return 'Selesai';
      case TimerStatus.idle:
        return 'Siap Dimulai';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFocus = mode == TimerPhase.focus;
    final activeColor = isFocus
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;

    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mode.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: activeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formattedTime,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _statusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
