import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_track.dart';

class MusicService {
  Future<StreamManifest> getManifest(String videoId) async {
    try {
      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
      if (manifest.audioOnly == null || manifest.audioOnly.isEmpty) {
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

  final _youtube = YoutubeExplode();
  final audioPlayer = AudioPlayer();

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

  Future<void> playTrack(MusicTrack track) async {
    try {
      final currentSource = audioPlayer.audioSource;
      if (currentSource is ConcatenatingAudioSource) {
        final index = currentSource.children.indexWhere(
          (source) =>
              source is UriAudioSource &&
              source.tag is MusicTrack &&
              (source.tag as MusicTrack).id == track.id,
        );
        if (index != -1) {
          await audioPlayer.seek(Duration.zero, index: index);
          await audioPlayer.play();
          return;
        }
      }
      // 기존 플레이리스트가 없거나 트랙이 플레이리스트에 없으면 새로 생성
      // 단일 트랙만 재생할 경우에만 ConcatenatingAudioSource를 새로 만듦
      if (currentSource is! ConcatenatingAudioSource ||
          !(currentSource.children.any(
            (source) =>
                source is UriAudioSource &&
                source.tag is MusicTrack &&
                (source.tag as MusicTrack).id == track.id,
          ))) {
        final manifest = await getManifest(track.id);
        final audioStream = manifest.audioOnly.withHighestBitrate();
        await Future(() async {
          final audioSource = ConcatenatingAudioSource(
            children: [
              AudioSource.uri(
                Uri.parse(audioStream.url.toString()),
                tag: track,
              ),
            ],
          );
          await audioPlayer.setAudioSource(audioSource);
          await audioPlayer.play();
        });
      }
    } catch (e) {
      print('Error playing music: $e');
    }
  }

  Future<void> pause() async {
    await Future(() async {
      await audioPlayer.pause();
    });
  }

  Future<void> resume() async {
    await Future(() async {
      await audioPlayer.play();
    });
  }

  Future<void> stop() async {
    await Future(() async {
      await audioPlayer.stop();
    });
  }

  Future<void> dispose() async {
    await audioPlayer.dispose();
    _youtube.close();
  }
}
