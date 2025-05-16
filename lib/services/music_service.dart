import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:file_picker/file_picker.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:media_kit/media_kit.dart' as media_kit;
import '../models/music_track.dart';

class MusicService {
  String? _selectedDownloadPath;
  Future<yt.StreamManifest> getManifest(String videoId) async {
    try {
      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
      if (manifest.audioOnly.isEmpty) {
        throw Exception('No audio streams available for this video.');
      }
      return manifest;
    } on yt.VideoUnavailableException catch (e) {
      debugPrint('VideoUnavailableException for videoId $videoId: $e');
      throw Exception('Video is unavailable: $videoId');
    } catch (e) {
      debugPrint('Error fetching manifest for videoId $videoId: $e');
      rethrow;
    }
  }

  final _youtube = yt.YoutubeExplode();
  final audioPlayer = media_kit.Player();

  Future<List<MusicTrack>> searchMusic(String query) async {
    try {
      var searchResults = await _youtube.search.search(query);
      var tracks = <MusicTrack>[];

      for (var video in searchResults.take(10)) {
        tracks.add(MusicTrack.fromVideoInfo(video));
      }

      return tracks;
    } catch (e) {
      debugPrint('Error searching videos: $e');
      return [];
    }
  }

  Future<void> playTrack(MusicTrack track) async {
    int retryCount = 0;
    const int maxRetries = 3;
    while (retryCount < maxRetries) {
      try {
        final currentPlayerPlaylist = audioPlayer.state.playlist;
        final existingIndex = currentPlayerPlaylist.medias.indexWhere(
          (media) => media.extras?['music_track']?.id == track.id,
        );

        if (existingIndex != -1) {
          await audioPlayer.jump(existingIndex);
          await audioPlayer.play();
          return;
        }

        final manifest = await getManifest(track.id);
        final audioStream = manifest.audioOnly.withHighestBitrate();

        final media = media_kit.Media(
          audioStream.url.toString(),
          extras: {'music_track': track},
        );
        await audioPlayer.open(media_kit.Playlist([media]));
        await audioPlayer.play();
        return;
      } catch (e) {
        debugPrint('Error playing music (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount >= maxRetries) {
          debugPrint('Failed to play track after $maxRetries attempts.');
        } else {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
  }

  Future<void> pause() async {
    await audioPlayer.pause();
  }

  Future<void> resume() async {
    await audioPlayer.play();
  }

  Future<void> stop() async {
    await audioPlayer.stop();
  }

  Future<void> dispose() async {
    await audioPlayer.dispose();
    _youtube.close();
  }

  Future<String> _downloadSingleTrack(
    MusicTrack track,
    String downloadPath,
  ) async {
    try {
      final manifest = await getManifest(track.id);
      final yt.AudioOnlyStreamInfo audioStreamInfo =
          manifest.audioOnly.withHighestBitrate();

      final sanitizedTitle = track.title.replaceAll(
        RegExp(r'[\/:*?"<>|]'),
        '_',
      );
      final filePath = '$downloadPath/$sanitizedTitle.mp3';

      if (await File(filePath).exists()) {
        debugPrint('File already exists: $filePath');
        return filePath;
      }

      final file = File(filePath);
      final fileStream = file.openWrite();

      var stream = _youtube.videos.streamsClient.get(audioStreamInfo);

      await stream.pipe(fileStream);
      await fileStream.close();

      debugPrint('Download complete: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error downloading track ${track.title}: $e');
      final sanitizedTitle = track.title.replaceAll(
        RegExp(r'[\/:*?"<>|]'),
        '_',
      );
      final filePath = '$downloadPath/$sanitizedTitle.mp3';
      final file = File(filePath);
      if (await file.exists()) {
        try {
          await file.delete();
          debugPrint('Deleted partially downloaded file: $filePath');
        } catch (deleteError) {
          debugPrint(
            'Error deleting partially downloaded file $filePath: $deleteError',
          );
        }
      }
      rethrow;
    }
  }

  Future<void> downloadTrack(MusicTrack track) async {
    String? downloadDirectory = _selectedDownloadPath;
    if (downloadDirectory == null) {
      downloadDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '다운로드할 폴더를 선택하세요',
      );
      if (downloadDirectory == null) {
        debugPrint('폴더 선택이 취소되었습니다.');
        throw Exception('Download folder not selected.');
      }
      _selectedDownloadPath = downloadDirectory;
    }

    try {
      final filePath = await _downloadSingleTrack(track, downloadDirectory);
      if (filePath.isNotEmpty) {
        debugPrint('${track.title} downloaded to $filePath');
      } else {
        debugPrint('Failed to download ${track.title}');
      }
    } catch (e) {
      debugPrint('Error in downloadTrack for ${track.title}: $e');
      rethrow;
    }
  }

  Future<void> downloadMultipleTracks(List<MusicTrack> tracks) async {
    String? downloadDirectory = _selectedDownloadPath;
    if (downloadDirectory == null) {
      downloadDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '다운로드할 폴더를 선택하세요',
      );
      if (downloadDirectory == null) {
        debugPrint('폴더 선택이 취소되었습니다. 여러 곡 다운로드를 취소합니다.');
        throw Exception('Download folder not selected.');
      }
      _selectedDownloadPath = downloadDirectory;
    }

    debugPrint('${tracks.length}개 트랙 다운로드를 시작합니다. (백그라운드 실행)');

    int successCount = 0;
    int failCount = 0;

    List<Future<void>> downloadFutures =
        tracks.map((track) async {
          try {
            await _downloadSingleTrack(track, downloadDirectory!);
            successCount++;
          } catch (e) {
            debugPrint('Failed to download ${track.title}: $e');
            failCount++;
          }
        }).toList();

    try {
      await Future.wait(downloadFutures);
      debugPrint('모든 트랙 다운로드 시도 완료. 성공: $successCount, 실패: $failCount');
      if (failCount > 0) {}
    } catch (e) {
      debugPrint('여러 트랙 다운로드 중 오류 발생: $e');
    }
  }
}
