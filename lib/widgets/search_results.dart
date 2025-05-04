import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/music_track.dart';
import '../providers/music_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/playlist_dialog.dart';

class SearchResults extends ConsumerWidget {
  const SearchResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResults = ref.watch(searchResultsProvider);

    if (searchResults.isEmpty) {
      return const Center(
        child: Text('Enter a YouTube video ID to start playing'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // Space for player
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final track = searchResults[index];
        return _buildTrackTile(context, track, ref);
      },
    );
  }

  Widget _buildTrackTile(
    BuildContext context,
    MusicTrack track,
    WidgetRef ref,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          track.thumbnailUrl,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${track.artist} • ${_formatDuration(track.duration)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: () {
              final playlists = ref.read(playlistsProvider);
              if (playlists.isEmpty) {
                showDialog(
                  context: context,
                  builder: (context) => const PlaylistDialog(),
                );
              } else {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Add to Playlist'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: playlists.length,
                            itemBuilder: (context, index) {
                              final playlist = playlists[index];
                              return ListTile(
                                title: Text(playlist.name),
                                onTap: () {
                                  ref
                                      .read(playlistsProvider.notifier)
                                      .addTrackToPlaylist(playlist.id, track);
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Added "${track.title}" to "${playlist.name}"',
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              showDialog(
                                context: context,
                                builder: (context) => const PlaylistDialog(),
                              );
                            },
                            child: const Text('New Playlist'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              ref.read(currentTrackProvider.notifier).state = track;
              ref.read(musicServiceProvider).playTrack(track);
            },
          ),
        ],
      ),
      onTap: () {
        ref.read(currentTrackProvider.notifier).state = track;
        ref.read(musicServiceProvider).playTrack(track);
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
