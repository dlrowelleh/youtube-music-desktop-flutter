import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});

class PreferencesNotifier extends StateNotifier<Preferences> {
  final PreferencesService _service;

  PreferencesNotifier(this._service) : super(_service.loadPreferences());

  void setVolume(double volume) {
    state = state.copyWith(volume: volume);
    _service.savePreferences(state);
  }

  void setLastPlayedTrack(String trackId) {
    state = state.copyWith(lastPlayedTrackId: trackId);
    _service.savePreferences(state);
  }

  void addRecentPlaylist(String playlistId) {
    final recentPlaylists = List<String>.from(state.recentPlaylistIds);
    if (recentPlaylists.contains(playlistId)) {
      recentPlaylists.remove(playlistId);
    }
    recentPlaylists.insert(0, playlistId);
    if (recentPlaylists.length > 5) {
      recentPlaylists.removeLast();
    }
    state = state.copyWith(recentPlaylistIds: recentPlaylists);
    _service.savePreferences(state);
  }

  void toggleShuffle() {
    state = state.copyWith(shuffleEnabled: !state.shuffleEnabled);
    _service.savePreferences(state);
  }

  void toggleRepeat() {
    state = state.copyWith(repeatEnabled: !state.repeatEnabled);
    _service.savePreferences(state);
  }
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, Preferences>((ref) {
      final service = ref.watch(preferencesServiceProvider);
      return PreferencesNotifier(service);
    });
