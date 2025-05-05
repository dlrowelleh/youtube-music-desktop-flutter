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
      // 플레이리스트 비디오 가져오기
      final videos =
          await youtube.playlists
              .getVideos(playlist.youtubePlaylistId!)
              .toList();

      // 비디오를 MusicTrack 객체로 변환
      final tracks =
          videos
              .map(
                (video) => MusicTrack(
                  id: video.id.value,
                  title: video.title,
                  artist: video.author,
                  thumbnailUrl: video.thumbnails.highResUrl,
                  duration: video.duration ?? Duration.zero,
                  url:
                      'https://www.youtube.com/watch?v=${video.id.value}', // URL 필수 매개변수 추가
                ),
              )
              .toList();

      print('Fetched video IDs: ${tracks.map((track) => track.id).toList()}');

      // 플레이리스트 업데이트
      updatePlaylist(playlistId, tracks: tracks);
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
