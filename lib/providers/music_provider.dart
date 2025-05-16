import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import '../models/music_track.dart';
import '../services/music_service.dart';
import '../models/preferences.dart';
import '../providers/preferences_provider.dart';
import 'package:media_kit/media_kit.dart';

final musicServiceProvider = Provider((ref) {
  final service = MusicService();
  ref.onDispose(() => service.dispose());
  return service;
});

final searchResultsProvider =
    StateNotifierProvider<SearchResultsNotifier, List<MusicTrack>>(
      (ref) => SearchResultsNotifier(ref.watch(musicServiceProvider)),
    );

final currentTrackProvider =
    StateNotifierProvider<CurrentTrackNotifier, MusicTrack?>(
      (ref) => CurrentTrackNotifier(
        ref.watch(musicServiceProvider),
        ref.watch(preferencesProvider.notifier),
        ref,
      ),
    );

final playlistTracksProvider =
    StateNotifierProvider<PlaylistTracksNotifier, List<MusicTrack>>(
      (ref) => PlaylistTracksNotifier(ref.watch(musicServiceProvider), ref),
    );

// UI 스레드에서 코드를 실행하기 위한 헬퍼 함수
Future<T> runOnUIThread<T>(Future<T> Function() callback) async {
  Completer<T> completer = Completer<T>();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final result = await callback();
      completer.complete(result);
    } catch (e) {
      completer.completeError(e);
    }
  });
  return completer.future;
}

class PlaylistTracksNotifier extends StateNotifier<List<MusicTrack>> {
  final MusicService _musicService;
  final Ref _ref;
  List<MusicTrack> _currentPlaylist = [];
  int _currentIndex = -1;
  StreamSubscription? _playlistSubscription;
  StreamSubscription? _playerStateSubscription;

  PlaylistTracksNotifier(this._musicService, this._ref) : super([]) {
    _listenToPlayerChanges();
  }

  void _listenToPlayerChanges() {
    _playlistSubscription?.cancel();
    _playlistSubscription = _musicService.player.stream.playlist.listen((
      playlist,
    ) {
      final newTracks =
          playlist.medias
              .map((media) => media.extras?['track'] as MusicTrack?)
              .where((track) => track != null)
              .cast<MusicTrack>()
              .toList();
      _currentPlaylist = newTracks;
      _currentIndex = playlist.index;
      state = List.from(_currentPlaylist);

      if (_currentIndex != -1 &&
          _currentPlaylist.isNotEmpty &&
          _currentIndex < _currentPlaylist.length) {
        _ref
            .read(currentTrackProvider.notifier)
            .setCurrentTrack(_currentPlaylist[_currentIndex]);
      }
    });

    _playerStateSubscription?.cancel();
    _playerStateSubscription = _musicService.player.stream.completed.listen((
      completed,
    ) {
      if (completed && _ref.read(preferencesProvider).repeatEnabled == false) {
        final isLastTrack = _currentIndex == _currentPlaylist.length - 1;
        if (isLastTrack && !_ref.read(preferencesProvider).shuffleEnabled) {
          // 다음 곡 없음 처리 또는 UI 업데이트
        } else if (_ref.read(preferencesProvider).shuffleEnabled) {
          // 셔플 모드일 경우, media_kit이 알아서 다음 곡을 선택하므로 별도 처리 불필요
        }
      }
    });
  }

  Future<void> playPlaylistTracks(
    List<MusicTrack> tracks,
    int startIndex,
  ) async {
    if (tracks.isEmpty) return;
    _currentPlaylist = List.from(tracks);
    _currentIndex = startIndex;
    state = List.from(_currentPlaylist);
    await _musicService.playTrack(
      tracks[startIndex],
      playlist: tracks,
      initialIndex: startIndex,
    );
    if (startIndex < tracks.length) {
      _ref
          .read(currentTrackProvider.notifier)
          .setCurrentTrack(tracks[startIndex]);
    }
  }

  Future<void> playShuffledTracks(List<MusicTrack> tracks) async {
    if (tracks.isEmpty) return;

    final shuffledTracks = List<MusicTrack>.from(tracks);
    final random = Random();
    for (int i = shuffledTracks.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = shuffledTracks[i];
      shuffledTracks[i] = shuffledTracks[j];
      shuffledTracks[j] = temp;
    }
    _currentPlaylist = shuffledTracks;
    _currentIndex = 0;
    state = List.from(_currentPlaylist);
    await _musicService.setShuffle(true);
    await _musicService.playTrack(
      shuffledTracks[0],
      playlist: shuffledTracks,
      initialIndex: 0,
    );
    _ref.read(currentTrackProvider.notifier).setCurrentTrack(shuffledTracks[0]);
    final prefsNotifier = _ref.read(preferencesProvider.notifier);
    prefsNotifier.state = prefsNotifier.state.copyWith(shuffleEnabled: true);
    _ref.read(preferencesServiceProvider).savePreferences(prefsNotifier.state);
  }

  Future<void> addTrackToPlaylist(MusicTrack track) async {
    _currentPlaylist.add(track);
    state = List.from(_currentPlaylist);
    if (_currentIndex != -1 &&
        _currentPlaylist.isNotEmpty &&
        _currentIndex < _currentPlaylist.length) {
      await _musicService.playTrack(
        _currentPlaylist[_currentIndex],
        playlist: _currentPlaylist,
        initialIndex: _currentIndex,
      );
    } else if (_currentPlaylist.isNotEmpty) {
      await _musicService.playTrack(
        _currentPlaylist[0],
        playlist: _currentPlaylist,
        initialIndex: 0,
      );
    }
  }

  Future<void> removeTrackFromPlaylist(String trackId) async {
    final initialTrackId =
        _currentIndex != -1 && _currentIndex < _currentPlaylist.length
            ? _currentPlaylist[_currentIndex].id
            : null;
    _currentPlaylist.removeWhere((t) => t.id == trackId);
    state = List.from(_currentPlaylist);

    if (_currentPlaylist.isEmpty) {
      await _musicService.stop();
      _ref.read(currentTrackProvider.notifier).setCurrentTrack(null);
      _currentIndex = -1;
      return;
    }

    if (initialTrackId == trackId || _currentIndex >= _currentPlaylist.length) {
      _currentIndex = _currentPlaylist.isNotEmpty ? 0 : -1;
    }

    if (_currentIndex != -1 && _currentPlaylist.isNotEmpty) {
      await _musicService.playTrack(
        _currentPlaylist[_currentIndex],
        playlist: _currentPlaylist,
        initialIndex: _currentIndex,
      );
      _ref
          .read(currentTrackProvider.notifier)
          .setCurrentTrack(_currentPlaylist[_currentIndex]);
    } else {
      await _musicService.stop();
      _ref.read(currentTrackProvider.notifier).setCurrentTrack(null);
    }
  }

  void clearPlaylist() {
    _currentPlaylist = [];
    _currentIndex = -1;
    state = [];
    _musicService.stop();
    _ref.read(currentTrackProvider.notifier).setCurrentTrack(null);
  }

  @override
  void dispose() {
    _playlistSubscription?.cancel();
    _playerStateSubscription?.cancel();
    super.dispose();
  }
}

class CurrentTrackNotifier extends StateNotifier<MusicTrack?> {
  final MusicService _musicService;
  final PreferencesNotifier _preferencesNotifier;
  final Ref _ref;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playlistStreamSubscription;
  StreamSubscription? _bufferingSubscription;
  StreamSubscription? _errorSubscription;

  CurrentTrackNotifier(this._musicService, this._preferencesNotifier, this._ref)
    : super(null) {
    _loadLastPlayedTrack();
    _listenToPlayerState();
  }

  void _listenToPlayerState() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = _musicService.player.stream.playing.listen((
      isPlaying,
    ) {
      if (state != null && !isPlaying) {
        // UI 업데이트 (예: 재생/일시정지 버튼 상태 변경)
      }
    });

    _playlistStreamSubscription?.cancel();
    _playlistStreamSubscription = _musicService.player.stream.playlist.listen((
      playlist,
    ) {
      final newIndex = playlist.index;
      if (newIndex != -1 && newIndex < playlist.medias.length) {
        final currentMedia = playlist.medias[newIndex];
        final track = currentMedia.extras?['track'] as MusicTrack?;
        if (track != null && state?.id != track.id) {
          setCurrentTrack(track);
          _preferencesNotifier.setLastPlayedTrack(track.id);
        }
      } else if (newIndex == -1 && playlist.medias.isEmpty) {
        setCurrentTrack(null);
      }
    });
  }

  Future<void> _loadLastPlayedTrack() async {
    final prefs = _ref.read(preferencesProvider);
    await _musicService.setVolume(prefs.volume);
    await _musicService.setShuffle(prefs.shuffleEnabled);
    await _musicService.setLoopMode(prefs.repeatEnabled);

    if (prefs.lastPlayedTrackId != null) {
      // 앱 시작 시 마지막 트랙 로드 및 재생 준비 로직 (MusicService와 협의 필요)
      // 현재는 setCurrentTrack만 호출하고, 실제 재생은 사용자 인터랙션으로 시작
      // 또는, PlaylistTracksNotifier에서 마지막 재생 목록을 불러와서 해당 트랙을 재생할 수 있음
      // final track = await fetchTrackDetailsById(prefs.lastPlayedTrackId); // 예시
      // if (track != null) setCurrentTrack(track);
    }
  }

  void setCurrentTrack(MusicTrack? track) {
    state = track;
  }

  Future<void> playTrack(MusicTrack track) async {
    await _musicService.playTrack(track);
    setCurrentTrack(track);
    _preferencesNotifier.setLastPlayedTrack(track.id);
  }

  Future<void> playNext() async {
    await _musicService.next();
  }

  Future<void> playPrevious() async {
    await _musicService.previous();
  }

  Future<void> stop() async {
    await _musicService.stop();
    state = null;
  }

  Future<void> resume() async {
    if (state != null) {
      await _musicService.resume();
    } else {
      final playlist = _ref.read(playlistTracksProvider);
      if (playlist.isNotEmpty) {
        await _ref
            .read(playlistTracksProvider.notifier)
            .playPlaylistTracks(playlist, 0);
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (_musicService.player.state.playing) {
      await _musicService.pause();
    } else {
      if (state != null) {
        await _musicService.resume();
      } else {
        final playlist = _ref.read(playlistTracksProvider);
        if (playlist.isNotEmpty) {
          await _ref
              .read(playlistTracksProvider.notifier)
              .playPlaylistTracks(playlist, 0);
        }
      }
    }
  }

  Future<void> setVolume(double volume) async {
    await _musicService.setVolume(volume);
    _preferencesNotifier.setVolume(volume);
  }

  Future<void> toggleShuffle() async {
    final newShuffleState = !_ref.read(preferencesProvider).shuffleEnabled;
    await _musicService.setShuffle(newShuffleState);
    _preferencesNotifier.state = _preferencesNotifier.state.copyWith(
      shuffleEnabled: newShuffleState,
    );
    _ref
        .read(preferencesServiceProvider)
        .savePreferences(_preferencesNotifier.state);
  }

  Future<void> toggleRepeat() async {
    final newRepeatState = !_ref.read(preferencesProvider).repeatEnabled;
    await _musicService.setLoopMode(newRepeatState);
    _preferencesNotifier.state = _preferencesNotifier.state.copyWith(
      repeatEnabled: newRepeatState,
    );
    _ref
        .read(preferencesServiceProvider)
        .savePreferences(_preferencesNotifier.state);
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playlistStreamSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }
}

class SearchResultsNotifier extends StateNotifier<List<MusicTrack>> {
  final MusicService _musicService;

  SearchResultsNotifier(this._musicService) : super([]);

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = [];
      return;
    }
    final results = await _musicService.searchMusic(query);
    state = results;
  }

  void clearSearchResults() {
    state = [];
  }
}
