import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:media_kit/media_kit.dart' hide Playlist;
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
  late Player _player;

  @override
  void initState() {
    super.initState();
    _player = ref.read(musicServiceProvider).player;
  }

  @override
  void dispose() {
    try {
      _player.pause();
    } catch (e) {
      print('PlaylistDetailsScreen dispose 중 플레이어 정지 오류: $e');
    }
    super.dispose();
  }

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
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
            icon: const Icon(Icons.download),
            tooltip: 'Download All Tracks',
            onPressed:
                tracks.isEmpty
                    ? null
                    : () async {
                      final musicService = ref.read(musicServiceProvider);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Starting download for ${widget.playlist.name}... (${tracks.length} tracks)',
                          ),
                        ),
                      );
                      await musicService.downloadMultipleTracks(tracks);
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
                              : () async {
                                try {
                                  await ref
                                      .read(playlistTracksProvider.notifier)
                                      .playShuffledTracks(
                                        List<MusicTrack>.from(tracks),
                                      );
                                } catch (e) {
                                  print('Error in shuffle button: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('셔플 재생 중 오류가 발생했습니다: $e'),
                                      ),
                                    );
                                  }
                                }
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
                            if (newIndex > oldIndex) newIndex -= 1;
                            final reorderedTracks = List<MusicTrack>.from(
                              tracks,
                            );
                            final item = reorderedTracks.removeAt(oldIndex);
                            reorderedTracks.insert(newIndex, item);
                            ref
                                .read(playlistsProvider.notifier)
                                .updatePlaylist(
                                  widget.playlist.id,
                                  tracks: reorderedTracks,
                                );
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
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.download_for_offline_outlined,
                                    ),
                                    tooltip: 'Download Track',
                                    onPressed: () async {
                                      final musicService = ref.read(
                                        musicServiceProvider,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Downloading ${track.title}...',
                                          ),
                                        ),
                                      );
                                      try {
                                        await musicService.downloadTrack(track);
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).hideCurrentSnackBar();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${track.title} downloaded.',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).hideCurrentSnackBar();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to download ${track.title}: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Remove from Playlist',
                                    onPressed: () {
                                      ref
                                          .read(playlistsProvider.notifier)
                                          .removeTrackFromPlaylist(
                                            widget.playlist.id,
                                            track.id,
                                          );
                                    },
                                  ),
                                ],
                              ),
                              onTap: () async {
                                try {
                                  await ref
                                      .read(playlistTracksProvider.notifier)
                                      .playPlaylistTracks(
                                        List<MusicTrack>.from(tracks),
                                        index,
                                      );
                                } catch (e) {
                                  print(
                                    'Error playing track from playlist details: $e',
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error playing track: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: EnhancedMusicPlayer(),
          ),
        ],
      ),
    );
  }
}
