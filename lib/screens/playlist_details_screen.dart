import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../models/playlist.dart';
import '../models/music_track.dart';
import '../providers/playlist_provider.dart';
import '../widgets/playlist_dialog.dart';
import '../widgets/enhanced_music_player.dart';
import '../providers/music_provider.dart';
import 'package:just_audio/just_audio.dart';

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
                                print(
                                  '트랙 클릭됨: 제목=${track.title}, 아티스트=${track.artist}, id=${track.id}',
                                );
                                final musicService = ref.read(
                                  musicServiceProvider,
                                );
                                final audioPlayer = musicService.audioPlayer;
                                final currentSource = audioPlayer.audioSource;
                                if (currentSource is ConcatenatingAudioSource) {
                                  final index = currentSource.children
                                      .indexWhere(
                                        (source) =>
                                            source is UriAudioSource &&
                                            source.tag is MusicTrack &&
                                            (source.tag as MusicTrack).id ==
                                                track.id,
                                      );
                                  if (index != -1) {
                                    print(
                                      'Playing track: ${track.title} by ${track.artist} (id: ${track.id})',
                                    );
                                    await audioPlayer.seek(
                                      Duration.zero,
                                      index: index,
                                    );
                                    await audioPlayer.play();
                                    return;
                                  }
                                }
                                // 1. Play only the selected track immediately
                                try {
                                  final manifest = await musicService
                                      .getManifest(track.id);
                                  if (manifest.audioOnly == null ||
                                      manifest.audioOnly.isEmpty) {
                                    throw Exception(
                                      'No audio streams available for this track.',
                                    );
                                  }
                                  final audioStream =
                                      manifest.audioOnly.withHighestBitrate();
                                  if (audioStream == null) {
                                    throw Exception(
                                      'No suitable audio stream found for this track.',
                                    );
                                  }
                                  final selectedSource = AudioSource.uri(
                                    Uri.parse(audioStream.url.toString()),
                                    tag: track,
                                  );
                                  await audioPlayer.setAudioSource(
                                    ConcatenatingAudioSource(
                                      children: [selectedSource],
                                    ),
                                    initialIndex: 0,
                                  );
                                  await audioPlayer.play();
                                  await ref
                                      .read(currentTrackProvider.notifier)
                                      .playTrack(track);
                                } catch (e) {
                                  print(
                                    'Failed to load selected track ${track.title}: $e',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to play track: ${track.title}',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                // 2. Load the rest of the tracks asynchronously and append them
                                Future(() async {
                                  for (final t in tracks) {
                                    if (t.id == track.id) continue;
                                    try {
                                      final m = await musicService.getManifest(
                                        t.id,
                                      );
                                      if (m.audioOnly == null ||
                                          m.audioOnly.isEmpty) {
                                        throw Exception(
                                          'No audio streams available for this track.',
                                        );
                                      }
                                      final s =
                                          m.audioOnly.withHighestBitrate();
                                      if (s == null) {
                                        throw Exception(
                                          'No suitable audio stream found for this track.',
                                        );
                                      }
                                      final audioSource = AudioSource.uri(
                                        Uri.parse(s.url.toString()),
                                        tag: t,
                                      );
                                      if (audioPlayer.audioSource
                                          is ConcatenatingAudioSource) {
                                        final concat =
                                            audioPlayer.audioSource
                                                as ConcatenatingAudioSource;
                                        await concat.add(audioSource);
                                      }
                                    } catch (e) {
                                      print(
                                        'Failed to load track ${t.title}: $e',
                                      );
                                    }
                                  }
                                });
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
