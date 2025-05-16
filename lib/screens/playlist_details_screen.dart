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
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    // try {
    //   // 화면이 dispose될 때 현재 음악을 정지할 필요는 없을 수 있습니다.
    //   // 사용자가 다른 화면으로 이동해도 음악은 계속 재생될 수 있도록 합니다.
    //   // 만약 플레이리스트 상세 화면을 벗어날 때 항상 음악을 정지시키고 싶다면 이 코드를 사용합니다.
    //   // final musicService = ref.read(musicServiceProvider);
    //   // musicService.audioPlayer.pause();
    // } catch (e) {
    //   debugPrint('Dispose 중 오디오 플레이어 정지 오류: $e');
    // }
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
                      int successCount = 0;
                      int failCount = 0;
                      for (final track in tracks) {
                        try {
                          await musicService.downloadTrack(track);
                          successCount++;
                          if (!mounted) return;
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            this.context,
                          );
                          scaffoldMessenger.hideCurrentSnackBar();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Downloaded: ${track.title}'),
                            ),
                          );
                        } catch (e) {
                          failCount++;
                          if (!mounted) return;
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            this.context,
                          );
                          scaffoldMessenger.hideCurrentSnackBar();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to download ${track.title}: $e',
                              ),
                            ),
                          );
                        }
                      }
                      if (!mounted) return;
                      final scaffoldMessenger = ScaffoldMessenger.of(
                        this.context,
                      );
                      scaffoldMessenger.hideCurrentSnackBar();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Download complete. Success: $successCount, Failed: $failCount',
                          ),
                        ),
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
                            Navigator.of(context).pop(); // Close dialog
                            Navigator.of(
                              context,
                            ).pop(); // Go back from playlist details
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
                                  final currentTrackNotifier = ref.read(
                                    currentTrackProvider.notifier,
                                  );
                                  final playlistTracksNotifier = ref.read(
                                    playlistTracksProvider.notifier,
                                  );

                                  // 셔플 재생 시작 및 첫 트랙 가져오기
                                  final firstShuffledTrack =
                                      await playlistTracksNotifier
                                          .playShuffledTracks(
                                            List<MusicTrack>.from(tracks),
                                          );

                                  // 현재 트랙 상태 업데이트
                                  if (firstShuffledTrack != null) {
                                    await currentTrackNotifier.playTrack(
                                      firstShuffledTrack,
                                    );
                                  } else {
                                    // 트랙이 없을 경우 처리 (예: 오류 메시지)
                                    if (!mounted || _disposed) return;
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text('셔플할 트랙이 없습니다.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error in shuffle button: $e');
                                  if (!mounted || _disposed) return;
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text('셔플 재생 중 오류가 발생했습니다: $e'),
                                    ),
                                  );
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
                            // Riverpod 상태를 업데이트하므로 setState는 필요하지 않을 수 있습니다.
                            // playlistsProvider가 상태를 관리합니다.
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = tracks.removeAt(oldIndex);
                            tracks.insert(newIndex, item);
                            ref
                                .read(playlistsProvider.notifier)
                                .updatePlaylist(
                                  widget.playlist.id,
                                  tracks: List<MusicTrack>.from(
                                    tracks,
                                  ), // 변경된 순서로 업데이트
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
                              title: Text(track.title),
                              subtitle: Text(track.artist),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  // setState(() {
                                  ref
                                      .read(playlistsProvider.notifier)
                                      .removeTrackFromPlaylist(
                                        widget.playlist.id,
                                        track.id,
                                      );
                                  // tracks.removeAt(index); // UI는 Riverpod 상태 변경에 따라 자동으로 업데이트됩니다.
                                  // });
                                },
                              ),
                              onTap: () async {
                                debugPrint(
                                  '트랙 클릭됨: 제목=${track.title}, 아티스트=${track.artist}, id=${track.id}',
                                );
                                final musicService = ref.read(
                                  musicServiceProvider,
                                );
                                final audioPlayer = musicService.audioPlayer;
                                final currentTrackNotifier = ref.read(
                                  currentTrackProvider.notifier,
                                );
                                final playlistTracksNotifier = ref.read(
                                  playlistTracksProvider.notifier,
                                );

                                // 현재 재생 목록에서 이미 선택된 트랙인지 확인 (media_kit 방식)
                                final currentPlayerPlaylist =
                                    audioPlayer.state.playlist;
                                final existingIndex = currentPlayerPlaylist
                                    .medias
                                    .indexWhere(
                                      (media) =>
                                          media.extras?['music_track']?.id ==
                                          track.id,
                                    );

                                if (existingIndex != -1 &&
                                    audioPlayer.state.playing) {
                                  debugPrint(
                                    '이미 재생 중인 목록의 트랙입니다. 해당 트랙으로 이동: ${track.title}',
                                  );
                                  await audioPlayer.jump(existingIndex);
                                  await audioPlayer
                                      .play(); // 이미 재생 중이면 필요 없을 수 있지만, 확실하게 하기 위해
                                  await currentTrackNotifier.playTrack(
                                    track,
                                  ); // 현재 트랙 상태 업데이트
                                  return;
                                }

                                // 1. 선택된 트랙을 포함한 전체 플레이리스트 재생 시작
                                // PlaylistTracksNotifier의 playPlaylistTracks를 사용하여 전체 목록을 로드하고 재생합니다.
                                // 이렇게 하면 지연 로딩 및 백그라운드 로딩이 적용됩니다.
                                try {
                                  await playlistTracksNotifier
                                      .playPlaylistTracks(tracks, index);
                                  await currentTrackNotifier.playTrack(track);
                                } catch (e) {
                                  debugPrint(
                                    'Failed to play playlist starting with track ${track.title}: $e',
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to play track: ${track.title}',
                                      ),
                                    ),
                                  );
                                }
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
