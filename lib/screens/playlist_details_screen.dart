import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playlist.dart';
import '../models/music_track.dart';
import '../providers/playlist_provider.dart';
import '../providers/music_provider.dart';
import '../widgets/playlist_dialog.dart';
import '../widgets/enhanced_music_player.dart';

class PlaylistDetailsScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailsScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailsScreen> createState() =>
      _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends ConsumerState<PlaylistDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future(() async {
      if (mounted) {
        await ref
            .read(searchResultsProvider.notifier)
            .getTracksById(widget.playlist.trackIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (context) => PlaylistDialog(playlist: widget.playlist),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Delete Playlist'),
                      content: Text(
                        'Are you sure you want to delete "${widget.playlist.name}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(playlistsProvider.notifier)
                                .deletePlaylist(widget.playlist.id);
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.playlist.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.playlist.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${tracks.length} tracks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(),
              Expanded(
                child:
                    tracks.isEmpty
                        ? const Center(
                          child: Text('No tracks in this playlist'),
                        )
                        : ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 120),
                          itemCount: tracks.length,
                          onReorder: (oldIndex, newIndex) {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final trackIds = List<String>.from(
                              widget.playlist.trackIds,
                            );
                            final item = trackIds.removeAt(oldIndex);
                            trackIds.insert(newIndex, item);
                            ref
                                .read(playlistsProvider.notifier)
                                .updatePlaylist(
                                  widget.playlist.id,
                                  name: widget.playlist.name,
                                  description: widget.playlist.description,
                                  trackIds: trackIds,
                                );
                          },
                          itemBuilder: (context, index) {
                            final track = tracks[index];
                            return ListTile(
                              key: ValueKey(track.id),
                              leading: Image.network(
                                track.thumbnailUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                              title: Text(track.title),
                              subtitle: Text(track.artist),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  ref
                                      .read(playlistsProvider.notifier)
                                      .removeTrackFromPlaylist(
                                        widget.playlist.id,
                                        track.id,
                                      );
                                },
                              ),
                              onTap: () {
                                ref.read(currentTrackProvider.notifier).state =
                                    track;
                                ref.read(musicServiceProvider).playTrack(track);
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: EnhancedMusicPlayer(),
          ),
        ],
      ),
    );
  }
}
