import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playlist.dart';
import '../models/music_track.dart';
import '../providers/playlist_provider.dart';
import '../widgets/playlist_dialog.dart';
import '../widgets/enhanced_music_player.dart';
import '../providers/music_provider.dart';

class PlaylistDetailsScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailsScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailsScreen> createState() =>
      _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends ConsumerState<PlaylistDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final tracks = widget.playlist.tracks;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          if (widget.playlist.youtubePlaylistId != null)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync with YouTube',
              onPressed: () {
                ref
                    .read(playlistsProvider.notifier)
                    .syncYoutubePlaylist(widget.playlist.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Syncing playlist...')),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${tracks.length} tracks',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.shuffle),
                      label: const Text('셔플 재생'),
                      onPressed:
                          tracks.isEmpty
                              ? null
                              : () {
                                final shuffled = List<MusicTrack>.from(tracks)
                                  ..shuffle();
                                // TODO: Pass shuffled list to player
                                // 기존의 EnhancedMusicPlayer를 사용하여 셔플 재생을 트리거
                                // 예시: 전역 Provider 또는 Service를 통해 트랙 리스트와 재생 인덱스를 설정
                                ref
                                    .read(playlistTracksProvider.notifier)
                                    .playShuffledTracks(shuffled);
                              },
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child:
                    tracks.isEmpty
                        ? const Center(
                          child: Text('No tracks in this playlist.'),
                        )
                        : ReorderableListView.builder(
                          itemCount: tracks.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = tracks.removeAt(oldIndex);
                              tracks.insert(newIndex, item);
                              ref
                                  .read(playlistsProvider.notifier)
                                  .updatePlaylist(
                                    widget.playlist.id,
                                    tracks: List<MusicTrack>.from(tracks),
                                  );
                            });
                          },
                          itemBuilder: (context, index) {
                            final track = tracks[index];
                            return ListTile(
                              key: ValueKey(track.id),
                              leading: Image.network(
                                track.thumbnailUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                              title: Text(track.title),
                              subtitle: Text(track.artist),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() {
                                    ref
                                        .read(playlistsProvider.notifier)
                                        .removeTrackFromPlaylist(
                                          widget.playlist.id,
                                          track.id,
                                        );
                                    tracks.removeAt(index);
                                  });
                                },
                              ),
                              onTap: () async {
                                await ref
                                    .read(currentTrackProvider.notifier)
                                    .playTrack(track);
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
