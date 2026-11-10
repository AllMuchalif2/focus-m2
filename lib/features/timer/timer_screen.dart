import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../services/auth_service.dart';
import '../../services/media_service.dart';
import '../../services/timer_engine.dart';
import '../../services/timer_service.dart';
import '../sessions/sessions_history_screen.dart';
import '../stats/stats_screen.dart';
import 'widgets/finish_sheet.dart';
import 'widgets/media_selector_sheet.dart';
import 'widgets/timer_circle.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  bool _isFinishSheetOpen = false;
  late final TextEditingController _durationInputController;
  int? _lastPlanIndex;

  static const List<int> _presetMinutes = [15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _durationInputController = TextEditingController();
  }

  @override
  void dispose() {
    _durationInputController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final timerService = context.watch<TimerService>();

    if (_durationInputController.text != timerService.totalSessionMinutes.toString()) {
      _durationInputController.text = timerService.totalSessionMinutes.toString();
    }

    if (_lastPlanIndex != null &&
        _lastPlanIndex != timerService.currentPlanIndex &&
        timerService.isRunning) {
      final isBreak = timerService.phase.isBreak;
      final msg = isBreak
          ? 'Sesi Fokus Selesai! Waktunya istirahat (${timerService.phase.displayName}).'
          : 'Waktu Istirahat Selesai! Mari mulai fokus kembali.';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
    _lastPlanIndex = timerService.currentPlanIndex;

    if (timerService.isCompleted && !_isFinishSheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFinishSheet(timerService.mode, Duration(minutes: timerService.totalSessionMinutes));
      });
    }
  }

  void _openFinishSheet(TimerMode mode, Duration duration) {
    if (!mounted || _isFinishSheetOpen) return;
    setState(() => _isFinishSheetOpen = true);

    context.read<MediaService>().playAlarm();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FinishSheet(
        completedMode: mode,
        completedDuration: duration,
      ),
    ).whenComplete(() {
      if (mounted) {
        context.read<MediaService>().stopAlarm();
        setState(() => _isFinishSheetOpen = false);
      }
    });
  }

  String _getBreakdownText(int totalMinutes) {
    if (totalMinutes <= 25) {
      return '$totalMinutes menit fokus penuh';
    }
    final blocks = totalMinutes ~/ 30;
    final remainder = totalMinutes % 30;
    if (blocks > 0 && remainder == 0) {
      return '$blocks sesi fokus (25m) + $blocks sesi istirahat (5m)';
    }
    return '$totalMinutes menit: fokus 25m bergantian dengan istirahat otomatis';
  }

  Future<void> _onWillPop(TimerService timerService, MediaService mediaService) async {
    final isSessionActive = timerService.isRunning || timerService.isPaused;
    if (!isSessionActive) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        await SystemNavigator.pop();
      }
      return;
    }

    final theme = Theme.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sesi Masih Berjalan',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Keluar sekarang akan menghentikan timer dan musik yang sedang berjalan.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, 'stay'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Tetap di Sini',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, 'stop'),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Hentikan Sesi'),
            ),
          ],
        ),
      ),
    );

    if (result == 'stop') {
      await timerService.stop();
      await mediaService.stopAmbience();
    }
  }

  Future<void> _confirmLogout() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: theme.colorScheme.error,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Keluar Akun?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Kamu akan keluar dari akun ini. Sesi yang sedang berjalan akan dihentikan.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Keluar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<TimerService>().stop();
      if (mounted) {
        await context.read<MediaService>().stopAmbience();
      }
      if (mounted) {
        await context.read<AuthService>().logout();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerService = context.watch<TimerService>();
    final mediaService = context.watch<MediaService>();
    final theme = Theme.of(context);
    final isIdle = timerService.isIdle;
    final hasVideo = mediaService.currentVideoUrl != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop(timerService, mediaService);
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Focus'),
        actions: [
          IconButton(
            icon: Icon(
              mediaService.currentAmbienceUrl != null || mediaService.currentVideoUrl != null
                  ? Icons.music_note
                  : Icons.music_note_outlined,
            ),
            tooltip: 'Media & Ambience',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const MediaSelectorSheet(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Statistik',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StatsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Sesi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SessionsHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasVideo &&
              mediaService.videoController != null &&
              mediaService.isVideoInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: mediaService.videoController!.value.size.width > 0
                      ? mediaService.videoController!.value.size.width
                      : 9,
                  height: mediaService.videoController!.value.size.height > 0
                      ? mediaService.videoController!.value.size.height
                      : 16,
                  child: VideoPlayer(mediaService.videoController!),
                ),
              ),
            ),
          if (hasVideo)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Column(
                      children: [
                        if (isIdle) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Pilih Durasi Sesi',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _presetMinutes.map((mins) {
                              final isSelected = timerService.totalSessionMinutes == mins;
                              return ChoiceChip(
                                label: Text('${mins}m'),
                                selected: isSelected,
                                onSelected: (_) {
                                  _durationInputController.text = mins.toString();
                                  timerService.setTotalMinutes(mins);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Ketik durasi custom:',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 86,
                                height: 40,
                                child: TextField(
                                  controller: _durationInputController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    suffixText: 'm',
                                  ),
                                  onChanged: (val) {
                                    final parsed = int.tryParse(val);
                                    if (parsed != null && parsed >= 1) {
                                      timerService.setTotalMinutes(parsed);
                                    }
                                  },
                                  onSubmitted: (val) {
                                    final parsed = int.tryParse(val);
                                    final valid = (parsed == null || parsed < 1) ? 1 : parsed;
                                    _durationInputController.text = valid.toString();
                                    timerService.setTotalMinutes(valid);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getBreakdownText(timerService.totalSessionMinutes),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Fase ${timerService.currentPlanIndex + 1} dari ${timerService.totalPlansCount} • Total Sesi: ${timerService.totalSessionMinutes}m',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        TimerCircle(
                          formattedTime: timerService.formattedRemaining,
                          progress: timerService.progress,
                          mode: timerService.phase,
                          status: timerService.status,
                        ),
                        const Spacer(),
                        _buildControlButtons(context, timerService, theme),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
        ],
      ),
    ),
  );
  }

  Widget _buildControlButtons(
    BuildContext context,
    TimerService timerService,
    ThemeData theme,
  ) {
    if (timerService.isInitial) {
      return SizedBox(
        width: 220,
        height: 52,
        child: FilledButton.icon(
          onPressed: () => timerService.start(),
          icon: const Icon(Icons.play_arrow),
          label: Text(
            'Mulai ${timerService.totalSessionMinutes} Menit',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    if (timerService.isRunning) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => timerService.pause(),
              icon: const Icon(Icons.pause),
              label: const Text('Jeda'),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => timerService.stop(),
              icon: const Icon(Icons.stop),
              label: const Text('Batal'),
            ),
          ),
        ],
      );
    }

    if (timerService.isPaused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => timerService.resume(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lanjut'),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => timerService.stop(),
              icon: const Icon(Icons.stop),
              label: const Text('Reset'),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: 200,
      height: 52,
      child: FilledButton.icon(
        onPressed: () => _openFinishSheet(
          timerService.mode,
          Duration(minutes: timerService.totalSessionMinutes),
        ),
        icon: const Icon(Icons.check),
        label: const Text('Selesaikan', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
