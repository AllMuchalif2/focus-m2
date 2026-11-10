import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../services/media_service.dart';

class MediaSelectorSheet extends StatelessWidget {
  const MediaSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaService = context.watch<MediaService>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Media & Suara Ambience',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Suara Latar (Ambience)',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Mati'),
                selected: mediaService.currentAmbienceUrl == null,
                onSelected: (_) => mediaService.stopAmbience(),
              ),
              ChoiceChip(
                label: const Text('Hujan'),
                avatar: const Icon(Icons.water_drop_outlined, size: 16),
                selected: mediaService.currentAmbienceUrl == AppConstants.audioRain,
                onSelected: (_) => mediaService.playAmbience(AppConstants.audioRain),
              ),
              ChoiceChip(
                label: const Text('Lofi'),
                avatar: const Icon(Icons.headphones_outlined, size: 16),
                selected: mediaService.currentAmbienceUrl == AppConstants.audioLofi,
                onSelected: (_) => mediaService.playAmbience(AppConstants.audioLofi),
              ),
            ],
          ),
          if (mediaService.currentAmbienceUrl != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.volume_down, size: 20),
                Expanded(
                  child: Slider(
                    value: mediaService.ambienceVolume,
                    onChanged: (val) => mediaService.setAmbienceVolume(val),
                  ),
                ),
                const Icon(Icons.volume_up, size: 20),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Video Latar Belakang',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Mati'),
                selected: mediaService.currentVideoUrl == null,
                onSelected: (_) => mediaService.setVideoBackground(null),
              ),
              ChoiceChip(
                label: const Text('Kereta'),
                avatar: const Icon(Icons.train_outlined, size: 16),
                selected: mediaService.currentVideoUrl == AppConstants.videoTrain,
                onSelected: (_) => mediaService.setVideoBackground(AppConstants.videoTrain),
              ),
              ChoiceChip(
                label: const Text('Hutan'),
                avatar: const Icon(Icons.forest_outlined, size: 16),
                selected: mediaService.currentVideoUrl == AppConstants.videoForest,
                onSelected: (_) => mediaService.setVideoBackground(AppConstants.videoForest),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
