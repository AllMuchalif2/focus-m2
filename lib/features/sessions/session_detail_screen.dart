import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/session_record.dart';
import '../../data/repositories/session_repository.dart';
import '../../services/auth_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final SessionRecord session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final TextEditingController _reflectionController;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _reflectionController = TextEditingController(text: widget.session.reflection);
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year, $hour:$minute WIB';
  }

  Future<void> _updateReflection() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await context.read<SessionRepository>().updateReflection(
            user.id,
            widget.session.id,
            _reflectionController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refleksi berhasil diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui refleksi: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Sesi?'),
        content: const Text('Sesi ini akan dihapus permanen dari riwayat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await context
          .read<SessionRepository>()
          .deleteSession(user.id, widget.session.id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi telah dihapus.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus sesi: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFocus = widget.session.mode == 'focus';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Sesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus Sesi',
            onPressed: _isDeleting ? null : _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: isFocus
                          ? theme.colorScheme.primary.withValues(alpha: 0.2)
                          : theme.colorScheme.secondary.withValues(alpha: 0.2),
                      child: Icon(
                        isFocus ? Icons.psychology_outlined : Icons.coffee_outlined,
                        size: 32,
                        color: isFocus
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isFocus ? 'Sesi Fokus' : 'Sesi Istirahat',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.session.durationMinutes} Menit',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDateTime(widget.session.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Refleksi Catatan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reflectionController,
              maxLength: 280,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Tulis refleksi kegiatanmu di sesi ini...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : _updateReflection,
              icon: const Icon(Icons.save_outlined),
              label: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan Perubahan Refleksi'),
            ),
          ],
        ),
      ),
    );
  }
}
