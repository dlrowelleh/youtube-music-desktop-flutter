import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import 'package:media_kit/media_kit.dart';
import '../models/music_track.dart';

class MusicService {
  String? _selectedDownloadPath;
  final _youtube = YoutubeExplode();
  final player = Player();

  MusicService() {
    // MediaKit.ensureInitialized(); // main.dart에서 호출하므로 제거
  }

  Future<StreamManifest> getManifest(String videoId) async {
    try {
      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
      if (manifest.audioOnly.isEmpty) {
        throw Exception('No audio streams available for this video.');
      }
      return manifest;
    } on VideoUnavailableException catch (e) {
      print('VideoUnavailableException for videoId $videoId: $e');
      throw Exception('Video is unavailable: $videoId');
    } catch (e) {
      print('Error fetching manifest for videoId $videoId: $e');
      rethrow;
    }
  }

  Future<List<MusicTrack>> searchMusic(String query) async {
    try {
      var searchResults = await _youtube.search.search(query);
      var tracks = <MusicTrack>[];

      for (var video in searchResults.take(10)) {
        tracks.add(MusicTrack.fromVideoInfo(video));
      }

      return tracks;
    } catch (e) {
      print('Error searching videos: $e');
      return [];
    }
  }

  Future<void> playTrack(
    MusicTrack track, {
    List<MusicTrack>? playlist,
    int initialIndex = 0,
  }) async {
    int retryCount = 0;
    const int maxRetries = 3;
    while (retryCount < maxRetries) {
      try {
        final manifest = await getManifest(track.id);
        final audioStream = manifest.audioOnly.withHighestBitrate();
        final media = Media(
          audioStream.url.toString(),
          extras: {'track': track},
        );

        final currentPlaylistState = player.state.playlist;
        final currentMedia =
            currentPlaylistState.medias.isNotEmpty &&
                    currentPlaylistState.index >= 0
                ? currentPlaylistState.medias[currentPlaylistState.index]
                : null;

        bool isSameTrackPlaying =
            currentMedia?.extras?['track']?.id == track.id;

        if (isSameTrackPlaying) {
          await player.play();
          return;
        }

        if (playlist != null && playlist.isNotEmpty) {
          List<Media> mediaPlaylist = [];
          for (var item in playlist) {
            try {
              final itemManifest = await getManifest(item.id);
              final itemAudioStream =
                  itemManifest.audioOnly.withHighestBitrate();
              mediaPlaylist.add(
                Media(itemAudioStream.url.toString(), extras: {'track': item}),
              );
            } catch (e) {
              print("Error getting manifest for ${item.id} in playlist: $e");
            }
          }

          if (mediaPlaylist.isNotEmpty) {
            final int trackIndexInPlaylist = mediaPlaylist.indexWhere(
              (m) => m.extras?['track']?.id == track.id,
            );
            await player.open(
              Playlist(
                mediaPlaylist,
                index: trackIndexInPlaylist >= 0 ? trackIndexInPlaylist : 0,
              ),
            );
            await player.play();
          } else {
            print("플레이리스트의 모든 트랙을 로드할 수 없어 재생을 시작할 수 없습니다.");
            return;
          }
        } else {
          await player.open(Playlist([media]));
          await player.play();
        }
        return;
      } catch (e) {
        print('Error playing music (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount >= maxRetries) {
          print('Failed to play track after $maxRetries attempts.');
          return;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> playPlaylist(List<MusicTrack> tracks, int initialIndex) async {
    if (tracks.isEmpty) return;
    await playTrack(
      tracks[initialIndex],
      playlist: tracks,
      initialIndex: initialIndex,
    );
  }

  Future<void> pause() async {
    await player.pause();
  }

  Future<void> resume() async {
    await player.play();
  }

  Future<void> stop() async {
    await player.stop();
  }

  Future<void> next() async {
    await player.next();
  }

  Future<void> previous() async {
    await player.previous();
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await player.setVolume(volume * 100);
  }

  Future<void> setShuffle(bool shuffle) async {
    await player.setShuffle(shuffle);
  }

  Future<void> setLoopMode(bool repeatEnabled) async {
    await player.setPlaylistMode(
      repeatEnabled ? PlaylistMode.loop : PlaylistMode.none,
    );
  }

  Future<void> dispose() async {
    await player.dispose();
    _youtube.close();
  }

  Future<String> _downloadSingleTrack(
    MusicTrack track,
    String downloadPath,
  ) async {
    try {
      final manifest = await getManifest(track.id);
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      final sanitizedTitle = track.title.replaceAll(
        RegExp(r'[\/:*?"<>|]'),
        '_',
      );
      final filePath = '$downloadPath/$sanitizedTitle.mp3';

      if (await File(filePath).exists()) {
        print('File already exists: $filePath');
        return filePath;
      }

      final file = File(filePath);
      final fileStream = file.openWrite();

      var stream = _youtube.videos.streamsClient.get(audioStreamInfo);

      await stream.pipe(fileStream);
      await fileStream.close();

      print('Download complete: $filePath');
      return filePath;
    } catch (e) {
      print('Error downloading track ${track.title}: $e');
      final sanitizedTitle = track.title.replaceAll(
        RegExp(r'[\/:*?"<>|]'),
        '_',
      );
      final filePath = '$downloadPath/$sanitizedTitle.mp3';
      final file = File(filePath);
      if (await file.exists()) {
        try {
          await file.delete();
          print('Deleted partially downloaded file: $filePath');
        } catch (deleteError) {
          print(
            'Error deleting partially downloaded file $filePath: $deleteError',
          );
        }
      }
      return '';
    }
  }

  Future<void> downloadTrack(MusicTrack track) async {
    String? downloadDirectory = _selectedDownloadPath;
    if (downloadDirectory == null) {
      downloadDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '다운로드할 폴더를 선택하세요',
      );
      if (downloadDirectory == null) {
        print('폴더 선택이 취소되었습니다.');
        return;
      }
      _selectedDownloadPath = downloadDirectory;
    }
    _downloadSingleTrack(track, downloadDirectory)
        .then((filePath) {
          if (filePath.isNotEmpty) {
            print('${track.title} downloaded to $filePath');
          } else {
            print('Failed to download ${track.title}');
          }
        })
        .catchError((e) {
          print('Error in downloadTrack for ${track.title}: $e');
        });
  }

  Future<void> downloadMultipleTracks(List<MusicTrack> tracks) async {
    String? downloadDirectory = _selectedDownloadPath;
    if (downloadDirectory == null) {
      downloadDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '다운로드할 폴더를 선택하세요',
      );
      if (downloadDirectory == null) {
        print('폴더 선택이 취소되었습니다. 여러 곡 다운로드를 취소합니다.');
        return;
      }
      _selectedDownloadPath = downloadDirectory;
    }

    List<Future<String>> downloadFutures = [];
    for (var track in tracks) {
      downloadFutures.add(_downloadSingleTrack(track, downloadDirectory));
    }

    print('${tracks.length}개 트랙 다운로드를 시작합니다. (백그라운드 실행)');
  }
}
