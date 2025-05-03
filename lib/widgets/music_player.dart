import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/music_track.dart';
import '../providers/music_provider.dart';

class MusicPlayer extends ConsumerWidget {
  const MusicPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(currentTrackProvider);

    if (currentTrack == null) return const SizedBox.shrink();

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.network(
            currentTrack.thumbnailUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentTrack.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  currentTrack.artist,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: () {
              ref.read(currentTrackProvider.notifier).stop();
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () {
                  ref.read(currentTrackProvider.notifier).resume();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
