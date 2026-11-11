import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/session_record.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/timer_service.dart';

class FinishSheet extends StatefulWidget {
  final Duration completedDuration;

  const FinishSheet({
    super.key,
    required this.completedDuration,
  });

  @override
  State<FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<FinishSheet> {
  final _reflectionController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _saveSession() async {
    setState(() => _isSaving = true);

    try {
      final user = context.read<AuthService>().currentUser;
      if (user != null) {
        final session = SessionRecord(
          id: '',
          userId: user.id,
          mode: 'focus',
          durationMinutes: widget.completedDuration.inMinutes,
          reflection: _reflectionController.text.trim(),
          hasProof: false,
          createdAt: DateTime.now(),
        );

        await context.read<SessionRepository>().createSession(user.id, session);
      }

      if (!mounted) return;
      final timerService = context.read<TimerService>();
      await timerService.stop();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi berhasil disimpan.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan sesi: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sesi Fokus Selesai!',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Durasi: ${widget.completedDuration.inMinutes} menit',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _reflectionController,
            maxLength: 280,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Refleksi Sesi',
              hintText: 'Apa yang berhasil kamu selesaikan? Bagaimana fokusmu tadi?',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSaving ? null : _saveSession,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan & Selesai'),
          ),
        ],
      ),
    );
  }
}
