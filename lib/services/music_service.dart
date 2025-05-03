import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_track.dart';

class MusicService {
  final _youtube = YoutubeExplode();
  final audioPlayer = AudioPlayer();

  Future<List<MusicTrack>> searchMusic(String query) async {
    try {
      var videos = await _youtube.search.search(query);
      return videos.map((video) => MusicTrack.fromVideoInfo(video)).toList();
    } catch (e) {
      print('Error searching music: $e');
      return [];
    }
  }

  Future<void> playTrack(MusicTrack track) async {
    try {
      final manifest = await _youtube.videos.streamsClient.getManifest(
        track.id,
      );
      final audioStream = manifest.audioOnly.withHighestBitrate();
      // Ensure audio operations run on platform thread
      await Future(() async {
        await audioPlayer.setUrl(audioStream.url.toString());
        await audioPlayer.play();
      });
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
