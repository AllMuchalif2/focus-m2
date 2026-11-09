import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/media_service.dart';
import '../../services/timer_engine.dart';
import '../../services/timer_service.dart';
import '../sessions/sessions_history_screen.dart';
import '../stats/stats_screen.dart';
import 'widgets/finish_sheet.dart';
import 'widgets/media_selector_sheet.dart';
import 'widgets/timer_circle.dart';
import 'widgets/video_timer_view.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  bool _isFinishSheetOpen = false;
  late final TextEditingController _durationInputController;

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

  @override
  Widget build(BuildContext context) {
    final timerService = context.watch<TimerService>();
    final mediaService = context.watch<MediaService>();
    final theme = Theme.of(context);
    final isIdle = timerService.isIdle;
    final hasVideo = mediaService.currentVideoUrl != null;

    return Scaffold(
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
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body: SafeArea(
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
                        if (hasVideo) ...[
                          const SizedBox(height: 16),
                          VideoTimerView(
                            controller: mediaService.videoController,
                            isInitialized: mediaService.isVideoInitialized,
                            formattedTime: timerService.formattedRemaining,
                            progress: timerService.progress,
                            phase: timerService.phase,
                            status: timerService.status,
                          ),
                          const Spacer(),
                        ] else ...[
                          const Spacer(),
                          TimerCircle(
                            formattedTime: timerService.formattedRemaining,
                            progress: timerService.progress,
                            mode: timerService.phase,
                            status: timerService.status,
                          ),
                          const Spacer(),
                        ],
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
