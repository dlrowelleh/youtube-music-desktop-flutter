import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'dart:convert';
import '../models/playlist.dart';
import 'preferences_provider.dart';
import '../models/music_track.dart';
import 'package:uuid/uuid.dart';

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
      state =
          playlistsJson
              .map(
                (json) =>
                    Playlist.fromJson(jsonDecode(json) as Map<String, dynamic>),
              )
              .toList();
    }
  }

  Future<void> _savePlaylists() async {
    final playlistsJson =
        state.map((playlist) => jsonEncode(playlist.toJson())).toList();
    await _prefs.setStringList(_key, playlistsJson);
  }

  void createPlaylist(
    String name, {
    String description = '',
    List<MusicTrack>? tracks,
    String? youtubePlaylistUrl,
    String? youtubePlaylistId,
  }) {
    final playlist = Playlist(
      id: const Uuid().v4(),
      name: name,
      description: description,
      tracks: tracks ?? [],
      youtubePlaylistUrl: youtubePlaylistUrl,
      youtubePlaylistId: youtubePlaylistId,
    );
    state = [...state, playlist];
    _savePlaylists();
  }

  void updatePlaylist(
    String id, {
    String? name,
    String? description,
    List<MusicTrack>? tracks,
    String? youtubePlaylistUrl,
    String? youtubePlaylistId,
  }) {
    state =
        state.map((playlist) {
          if (playlist.id == id) {
            return playlist.copyWith(
              name: name,
              description: description,
              tracks: tracks,
              youtubePlaylistUrl: youtubePlaylistUrl,
              youtubePlaylistId: youtubePlaylistId,
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

  void addTrackToPlaylist(String playlistId, MusicTrack track) {
    state =
        state.map((playlist) {
          if (playlist.id == playlistId &&
              !playlist.tracks.any((t) => t.id == track.id)) {
            return playlist.copyWith(tracks: [...playlist.tracks, track]);
          }
          return playlist;
        }).toList();
    _savePlaylists();
  }

  Future<void> syncYoutubePlaylist(String playlistId) async {
    final playlist = state.firstWhere((p) => p.id == playlistId);
    if (playlist.youtubePlaylistId == null) return;

    final youtube = yt.YoutubeExplode();
    try {
      final videos =
          await youtube.playlists
              .getVideos(playlist.youtubePlaylistId!)
              .toList();
      // TODO: You need to convert videoIds to MusicTrack objects before updating the playlist
      // For now, just print the video IDs
      final videoIds = videos.map((video) => video.id.value).toList();
      print('Fetched video IDs: $videoIds');
      // updatePlaylist(playlistId, tracks: ...); // Implement conversion to MusicTrack
    } catch (e) {
      print('Failed to sync YouTube playlist: $e');
      rethrow;
    } finally {
      youtube.close();
    }
  }

  void removeTrackFromPlaylist(String playlistId, String trackId) {
    state =
        state.map((playlist) {
          if (playlist.id == playlistId) {
            return playlist.copyWith(
              tracks:
                  playlist.tracks
                      .where((track) => track.id != trackId)
                      .toList(),
            );
          }
          return playlist;
        }).toList();
    _savePlaylists();
  }
}

// Remove duplicate import '../models/music_track.dart';
// Remove duplicate import 'package:uuid/uuid.dart';
// Ensure file ends with a single closing bracket for the class.
