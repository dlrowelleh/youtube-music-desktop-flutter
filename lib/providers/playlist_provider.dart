import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/playlist.dart';
import 'preferences_provider.dart';

final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, List<Playlist>>(
      (ref) => PlaylistsNotifier(ref.watch(sharedPreferencesProvider)),
    );

final currentPlaylistProvider = StateProvider<Playlist?>((ref) => null);

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  static const _key = 'playlists';
  final SharedPreferences _prefs;

  PlaylistsNotifier(this._prefs) : super([]) {
    _loadPlaylists();
  }

  void _loadPlaylists() {
    final playlistsJson = _prefs.getStringList(_key);
    if (playlistsJson != null) {
      state = playlistsJson
          .map((json) => Playlist.fromJson(jsonDecode(json)))
          .toList();
    }
  }

  Future<void> _savePlaylists() async {
    final playlistsJson = state
        .map((playlist) => jsonEncode(playlist.toJson()))
        .toList();
    await _prefs.setStringList(_key, playlistsJson);
  }

  void createPlaylist(String name, {String description = ''}) {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
    );
    state = [...state, playlist];
    _savePlaylists();
  }

  void updatePlaylist(String id, {String? name, String? description, List<String>? trackIds}) {
    state = state.map((playlist) {
      if (playlist.id == id) {
        return playlist.copyWith(
          name: name,
          description: description,
          trackIds: trackIds,
        );
      }
      return playlist;
    }).toList();
    _savePlaylists();
  }

  void deletePlaylist(String id) {
    state = state.where((playlist) => playlist.id != id).toList();
    _savePlaylists();
  }

  void addTrackToPlaylist(String playlistId, String trackId) {
    state = state.map((playlist) {
      if (playlist.id == playlistId &&
          !playlist.trackIds.contains(trackId)) {
        return playlist.copyWith(trackIds: [...playlist.trackIds, trackId]);
      }
      return playlist;
    }).toList();
    _savePlaylists();
  }

  void removeTrackFromPlaylist(String playlistId, String trackId) {
    state = state.map((playlist) {
      if (playlist.id == playlistId) {
        return playlist.copyWith(
          trackIds: playlist.trackIds.where((id) => id != trackId).toList(),
        );
      }
      return playlist;
    }).toList();
    _savePlaylists();
  }
}
