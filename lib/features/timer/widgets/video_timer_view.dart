import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../services/timer_engine.dart';

class VideoTimerView extends StatelessWidget {
  final VideoPlayerController? controller;
  final bool isInitialized;
  final String formattedTime;
  final double progress;
  final TimerPhase phase;
  final TimerStatus status;

  const VideoTimerView({
    super.key,
    required this.controller,
    required this.isInitialized,
    required this.formattedTime,
    required this.progress,
    required this.phase,
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
    final isFocus = phase == TimerPhase.focus;
    final activeColor = isFocus ? theme.colorScheme.primary : theme.colorScheme.secondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          phase.displayName,
          style: theme.textTheme.titleMedium?.copyWith(
            color: activeColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formattedTime,
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _statusLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: isInitialized && controller != null
                ? AspectRatio(
                    aspectRatio: controller!.value.aspectRatio > 0
                        ? controller!.value.aspectRatio
                        : 9 / 16,
                    child: VideoPlayer(controller!),
                  )
                : Container(
                    height: 180,
                    width: double.infinity,
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
