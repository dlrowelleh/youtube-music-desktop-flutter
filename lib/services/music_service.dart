import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_track.dart';

class MusicService {
  Future<StreamManifest> getManifest(String videoId) async {
    return await _youtube.videos.streamsClient.getManifest(videoId);
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
      // If a playlist is active, seek to the track in the playlist instead of resetting the audio source
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
      // Otherwise, create a new ConcatenatingAudioSource with just this track
      // This allows previous/next buttons to work consistently
      final manifest = await getManifest(track.id);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      await Future(() async {
        // Create a ConcatenatingAudioSource even for a single track
        // This makes the previous/next buttons behavior consistent
        final audioSource = ConcatenatingAudioSource(
          children: [
            AudioSource.uri(Uri.parse(audioStream.url.toString()), tag: track),
          ],
        );
        await audioPlayer.setAudioSource(audioSource);
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
