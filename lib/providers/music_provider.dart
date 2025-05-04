import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/music_track.dart';
import '../services/music_service.dart';
import '../models/preferences.dart';
import '../providers/preferences_provider.dart';
import 'package:just_audio/just_audio.dart';

final musicServiceProvider = Provider((ref) => MusicService());

final searchResultsProvider =
    StateNotifierProvider<SearchResultsNotifier, List<MusicTrack>>(
      (ref) => SearchResultsNotifier(ref.watch(musicServiceProvider)),
    );

final currentTrackProvider =
    StateNotifierProvider<CurrentTrackNotifier, MusicTrack?>(
      (ref) => CurrentTrackNotifier(
        ref.watch(musicServiceProvider),
        ref.watch(preferencesServiceProvider),
        ref.watch(searchResultsProvider.notifier),
      ),
    );

final playlistTracksProvider =
    StateNotifierProvider<PlaylistTracksNotifier, List<MusicTrack>>(
      (ref) => PlaylistTracksNotifier(ref.watch(musicServiceProvider)),
    );

class PlaylistTracksNotifier extends StateNotifier<List<MusicTrack>> {
  final MusicService _musicService;

  PlaylistTracksNotifier(this._musicService) : super([]);

  Future<void> playShuffledTracks(List<MusicTrack> tracks) async {
    if (tracks.isEmpty) return;
    state = tracks;
    // Fetch actual stream URLs for each track
    final List<AudioSource> audioSources = [];
    for (final track in tracks) {
      final manifest = await _musicService.getManifest(track.id);
      final audioStream = manifest.audioOnly.first;
      audioSources.add(
        AudioSource.uri(Uri.parse(audioStream.url.toString()), tag: track),
      );
    }
    await _musicService.audioPlayer.setAudioSource(
      ConcatenatingAudioSource(children: audioSources),
    );
    await _musicService.audioPlayer.setShuffleModeEnabled(true);
    await _musicService.audioPlayer.shuffle();
    await _musicService.audioPlayer.seek(Duration.zero, index: 0);
    await _musicService.audioPlayer.play();
  }
}

class SearchResultsNotifier extends StateNotifier<List<MusicTrack>> {
  final MusicService _musicService;

  SearchResultsNotifier(this._musicService) : super([]);

  Future<List<MusicTrack>> loadVideo(String videoId) async {
    if (videoId.isEmpty) {
      state = [];
      return [];
    }
    final results = await _musicService.searchMusic(videoId);
    state = results;
    return results;
  }
}

class CurrentTrackNotifier extends StateNotifier<MusicTrack?> {
  final MusicService _musicService;
  final PreferencesService _preferencesService;
  final SearchResultsNotifier _searchResults;

  CurrentTrackNotifier(
    this._musicService,
    this._preferencesService,
    this._searchResults,
  ) : super(null) {
    _restoreLastPlayedTrack();

    // 현재 재생 중인 트랙 상태 업데이트를 위한 리스너 추가
    _musicService.audioPlayer.currentIndexStream.listen((index) {
      if (index != null) {
        final currentSource = _musicService.audioPlayer.audioSource;
        if (currentSource is ConcatenatingAudioSource &&
            index < currentSource.children.length) {
          final source = currentSource.children[index];
          if (source is UriAudioSource && source.tag is MusicTrack) {
            state = source.tag as MusicTrack;
          }
        }
      }
    });
  }

  Future<void> _restoreLastPlayedTrack() async {
    final preferences = _preferencesService.loadPreferences();
    if (preferences.lastPlayedTrackId != null) {
      final tracks = await _searchResults.loadVideo(
        preferences.lastPlayedTrackId!,
      );
      if (tracks.isNotEmpty) {
        state = tracks.first;
        await _musicService.playTrack(tracks.first);
      }
    }
  }

  Future<void> playTrack(MusicTrack track) async {
    state = track;
    await _musicService.playTrack(track);
  }

  Future<void> pause() async {
    await _musicService.pause();
  }

  Future<void> resume() async {
    await _musicService.resume();
  }

  Future<void> stop() async {
    await _musicService.stop();
    state = null;
  }

  Future<void> playNext() async {
    await _musicService.audioPlayer.seekToNext();
  }

  Future<void> playPrevious() async {
    await _musicService.audioPlayer.seekToPrevious();
  }
}
