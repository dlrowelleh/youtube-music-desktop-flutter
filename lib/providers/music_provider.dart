import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/music_track.dart';
import '../services/music_service.dart';
import '../models/preferences.dart';
import '../providers/preferences_provider.dart';

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

class SearchResultsNotifier extends StateNotifier<List<MusicTrack>> {
  final MusicService _musicService;

  SearchResultsNotifier(this._musicService) : super([]);

  Future<List<MusicTrack>> search(String query) async {
    if (query.isEmpty) {
      state = [];
      return [];
    }
    final results = await _musicService.searchMusic(query);
    state = results;
    return results;
  }

  Future<List<MusicTrack>> getTracksById(List<String> trackIds) async {
    if (trackIds.isEmpty) return [];

    final allTracks = <MusicTrack>[];
    for (final trackId in trackIds) {
      final results = await _musicService.searchMusic(trackId);
      final matchingTrack =
          results.where((track) => track.id == trackId).toList();
      if (matchingTrack.isNotEmpty) {
        allTracks.add(matchingTrack.first);
      }
    }

    state = allTracks;
    return allTracks;
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
  }

  Future<void> _restoreLastPlayedTrack() async {
    final preferences = _preferencesService.loadPreferences();
    if (preferences.lastPlayedTrackId != null) {
      final tracks = await _searchResults.search(
        preferences.lastPlayedTrackId!,
      );
      final track = tracks.firstWhere(
        (track) => track.id == preferences.lastPlayedTrackId,
        orElse:
            () => MusicTrack(
              id: '',
              title: '',
              artist: '',
              thumbnailUrl: '',
              duration: Duration.zero,
              url: '',
            ),
      );
      if (track.id.isNotEmpty) {
        state = track;
        await _musicService.playTrack(track);
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
}
