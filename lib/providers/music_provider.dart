import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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
  // 지연 로딩을 위한 변수들
  final Map<String, AudioSource> _loadedAudioSources = {};
  ConcatenatingAudioSource? _concatenatingSource;
  List<MusicTrack> _allTracks = [];
  bool _isLoadingMore = false;
  int _preloadCount = 3; // 미리 로드할 트랙 수

  // 리스너 구독 관리
  StreamSubscription? _indexChangeSubscription;
  StreamSubscription? _shuffleModeSubscription;

  PlaylistTracksNotifier(this._musicService) : super([]);

  // 셔플된 트랙 재생 - 플레이리스트의 모든 트랙을 셔플하여 재생
  Future<MusicTrack?> playShuffledTracks(List<MusicTrack> tracks) async {
    print('DEBUG: playShuffledTracks 시작 - 트랙 수: ${tracks.length}');
    if (tracks.isEmpty) {
      print('DEBUG: 트랙 목록이 비어있어 셔플 불가');
      return null;
    }

    try {
      // 기존 재생 중지 - 앱 종료 문제로 인해 stop() 대신 pause() 사용
      print('DEBUG: 기존 재생 일시 중지 시도');
      try {
        await _musicService.audioPlayer.pause();
        // 현재 위치 초기화 (0으로 이동)
        await _musicService.audioPlayer.seek(Duration.zero);
        print('DEBUG: 기존 재생 일시 중지 및 위치 초기화 완료');
      } catch (e) {
        print('DEBUG: 기존 재생 일시 중지 중 오류: $e');
        // 오류가 발생해도 계속 진행
      }

      // 전체 트랙 리스트를 셔플 (Fisher-Yates 알고리즘)
      print('DEBUG: 전체 트랙 리스트 셔플 시작');
      final shuffledTracks = List<MusicTrack>.from(tracks);
      final random = Random();

      // Fisher-Yates 셔플 알고리즘 적용
      for (int i = shuffledTracks.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        // 두 요소 교환
        final temp = shuffledTracks[i];
        shuffledTracks[i] = shuffledTracks[j];
        shuffledTracks[j] = temp;
      }

      print('DEBUG: 트랙 셔플 완료 - 첫 번째 트랙: ${shuffledTracks.first.title}');

      // 셔플된 전체 트랙 목록 저장
      print('DEBUG: 상태 업데이트 - 셔플된 트랙 목록으로 설정');
      state = shuffledTracks;

      // 셔플된 플레이리스트 재생 시작 (첫 번째 트랙부터)
      print('DEBUG: 셔플된 플레이리스트 재생 시작');
      await playPlaylistTracks(shuffledTracks, 0);

      // 셔플 모드 활성화
      print('DEBUG: 셔플 모드 활성화');
      await runOnUIThread(() async {
        await _musicService.audioPlayer.setShuffleModeEnabled(true);
        print('DEBUG: 셔플 모드 설정 완료');
      });

      // 첫 번째 트랙 반환 (UI 업데이트용)
      print('DEBUG: 첫 번째 트랙 반환: ${shuffledTracks.first.title}');
      return shuffledTracks.first;
    } catch (e) {
      print('DEBUG: playShuffledTracks 오류 발생: $e');
      print('DEBUG: 오류 스택 트레이스:');
      print(StackTrace.current);
      return null;
    }
  }

  // 일반 플레이리스트 재생 - 지연 로딩 방식 적용 (최적화 버전)
  Future<void> playPlaylistTracks(
    List<MusicTrack> tracks,
    int startIndex,
  ) async {
    print(
      'DEBUG: playPlaylistTracks 시작 - 트랙 수: ${tracks.length}, 시작 인덱스: $startIndex',
    );
    if (tracks.isEmpty) {
      print('DEBUG: 트랙 목록이 비어있어 재생 불가');
      return;
    }

    try {
      // 기존 리스너 제거 및 재생 중지
      print('DEBUG: 기존 재생 정리 시작');
      await _cleanupCurrentPlayback();
      print('DEBUG: 기존 재생 정리 완료');

      // 전체 트랙 목록 저장
      print('DEBUG: 전체 트랙 목록 저장');
      _allTracks = List<MusicTrack>.from(tracks);
      state = _allTracks;

      // 초기화
      print('DEBUG: 오디오 소스 초기화');
      _loadedAudioSources.clear();
      _concatenatingSource = ConcatenatingAudioSource(children: []);
      print('DEBUG: ConcatenatingAudioSource 생성 완료');

      // 시작 트랙 주변의 트랙들 로드 - 첫 번째 트랙만 먼저 로드하여 재생 시작 시간 단축
      print('DEBUG: 초기 로드할 트랙 준비');
      final firstTrack = _allTracks[startIndex];
      print('DEBUG: 첫 번째 트랙 추가: ${firstTrack.title}');

      // 첫 번째 트랙만 로드
      print('DEBUG: 첫 번째 트랙 로드 시작');
      await _loadTracksToSource([firstTrack], 0);
      print('DEBUG: 첫 번째 트랙 로드 완료');

      // 오디오 소스 설정 - UI 스레드에서 실행되도록 함
      print('DEBUG: 오디오 소스 설정 시작');
      try {
        // WidgetsFlutterBinding 초기화 확인
        WidgetsFlutterBinding.ensureInitialized();
        print('DEBUG: WidgetsFlutterBinding 초기화 완료');

        // UI 스레드에서 오디오 소스 설정
        await runOnUIThread(() async {
          print('DEBUG: setAudioSource 호출 직전 (ConcatenatingAudioSource)');
          await _musicService.audioPlayer.setAudioSource(_concatenatingSource!);
          print('DEBUG: setAudioSource 호출 완료');
          return null;
        });
      } catch (setSourceError) {
        print('DEBUG: 오디오 소스 설정 중 오류: $setSourceError');
        throw setSourceError;
      }

      // 첫 트랙으로 이동 및 재생 시작 - UI 스레드에서 실행되도록 함
      print('DEBUG: 재생 시작 준비');
      try {
        await runOnUIThread(() async {
          print('DEBUG: seek 호출 직전');
          await _musicService.audioPlayer.seek(Duration.zero, index: 0);
          print('DEBUG: seek 호출 완료, play 호출 직전');
          await _musicService.audioPlayer.play();
          print('DEBUG: play 호출 완료');
          return null;
        });
      } catch (playError) {
        print('DEBUG: 재생 시작 중 오류: $playError');
        throw playError;
      }

      // 현재 인덱스 변경 시 다음 트랙 미리 로드하는 리스너 추가
      print('DEBUG: 인덱스 변경 리스너 설정 시작');
      _setupIndexChangeListener();
      print('DEBUG: 인덱스 변경 리스너 설정 완료');

      // 첫 번째 트랙 재생이 시작된 후 백그라운드에서 나머지 트랙 로드
      _loadRemainingTracksInBackground(startIndex);

      print('DEBUG: playPlaylistTracks 완료');
    } catch (e) {
      print('DEBUG: playPlaylistTracks 오류 발생: $e');
      print('DEBUG: 오류 스택 트레이스:');
      print(StackTrace.current);
    }
  }

  // 백그라운드에서 나머지 트랙 로드 (첫 번째 트랙 재생 시작 후)
  Future<void> _loadRemainingTracksInBackground(int startIndex) async {
    // 첫 번째 트랙 이후 preload 개수만큼 추가 트랙 로드
    final tracksToLoad = <MusicTrack>[];
    for (int i = 1; i <= _preloadCount; i++) {
      final nextIndex = startIndex + i;
      if (nextIndex < _allTracks.length) {
        tracksToLoad.add(_allTracks[nextIndex]);
      }
    }

    if (tracksToLoad.isNotEmpty) {
      print('DEBUG: 백그라운드에서 추가 트랙 로드 시작 - ${tracksToLoad.length}개');
      // 첫 번째 트랙 다음 위치에 추가 트랙 삽입
      await _loadTracksToSource(tracksToLoad, 1);
      print('DEBUG: 백그라운드 추가 트랙 로드 완료');
    }
  }

  // 현재 재생 중인 플레이리스트 정리
  Future<void> _cleanupCurrentPlayback() async {
    print('DEBUG: _cleanupCurrentPlayback 시작');
    try {
      // 현재 재생 중지 - 앱 종료 문제로 인해 stop() 대신 pause() 사용
      print('DEBUG: 현재 재생 일시 중지 시도');
      try {
        // UI 스레드에서 오디오 플레이어 작업 실행
        await runOnUIThread(() async {
          await _musicService.audioPlayer.pause();
          // 현재 위치 초기화 (0으로 이동)
          await _musicService.audioPlayer.seek(Duration.zero);
          print('DEBUG: 현재 재생 일시 중지 및 위치 초기화 완료');
          return null;
        });
      } catch (e) {
        print('DEBUG: 현재 재생 일시 중지 중 오류: $e');
        // 오류가 발생해도 계속 진행
      }

      // 리스너 제거 로직
      print('DEBUG: 인덱스 변경 리스너 제거 시도');
      if (_indexChangeSubscription != null) {
        await _indexChangeSubscription?.cancel();
        print('DEBUG: 인덱스 변경 리스너 제거 완료');
      } else {
        print('DEBUG: 인덱스 변경 리스너가 null임');
      }

      print('DEBUG: 셔플 모드 리스너 제거 시도');
      if (_shuffleModeSubscription != null) {
        await _shuffleModeSubscription?.cancel();
        print('DEBUG: 셔플 모드 리스너 제거 완료');
      } else {
        print('DEBUG: 셔플 모드 리스너가 null임');
      }

      // 메모리 정리
      print('DEBUG: 메모리 정리 시작');
      _isLoadingMore = false;
      print('DEBUG: isLoadingMore 플래그 초기화');

      if (_concatenatingSource != null) {
        try {
          print('DEBUG: 오디오 소스 클리어 시도');
          // UI 스레드에서 오디오 소스 클리어 실행
          await runOnUIThread(() async {
            await _concatenatingSource!.clear();
            print('DEBUG: 오디오 소스 클리어 완료');
            return null;
          });
        } catch (e) {
          print('DEBUG: 오디오 소스 클리어 중 오류: $e');
          print('DEBUG: 오류 스택 트레이스:');
          print(StackTrace.current);
        }
      } else {
        print('DEBUG: concatenatingSource가 null임');
      }
      print('DEBUG: _cleanupCurrentPlayback 완료');
    } catch (e) {
      print('DEBUG: _cleanupCurrentPlayback 중 오류 발생: $e');
      print('DEBUG: 오류 스택 트레이스:');
      print(StackTrace.current);
    }
  }

  // 매니페스트 캐시 - 트랙 ID를 키로 사용하여 매니페스트 저장
  final Map<String, StreamManifest> _manifestCache = {};

  // 트랙을 오디오 소스에 로드하는 헬퍼 메서드 (병렬 처리 최적화)
  Future<void> _loadTracksToSource(
    List<MusicTrack> tracksToLoad,
    int insertIndex,
  ) async {
    print(
      'DEBUG: _loadTracksToSource 시작 - 로드할 트랙 수: ${tracksToLoad.length}, 삽입 인덱스: $insertIndex',
    );
    if (tracksToLoad.isEmpty || _concatenatingSource == null) {
      print('DEBUG: 로드할 트랙이 없거나 concatenatingSource가 null임');
      return;
    }

    final audioSources = <AudioSource>[];
    print('DEBUG: 오디오 소스 배열 초기화');

    // 트랙 로딩 전에 현재 재생 상태 저장
    final wasPlaying = _musicService.audioPlayer.playing;
    print('DEBUG: 현재 재생 상태 저장: $wasPlaying');

    // 트랙 로딩 중 일시적으로 일시정지 (UI 스레드 동기화 문제 방지)
    if (wasPlaying) {
      try {
        await runOnUIThread(() async {
          await _musicService.audioPlayer.pause();
          print('DEBUG: 트랙 로딩을 위해 일시 정지');
          return null;
        });
      } catch (e) {
        print('DEBUG: 일시 정지 중 오류: $e');
      }
    }

    // 캐시된 오디오 소스 먼저 처리
    final uncachedTracks = <MusicTrack>[];
    for (final track in tracksToLoad) {
      // 이미 로드된 트랙이면 재사용
      if (_loadedAudioSources.containsKey(track.id)) {
        print('DEBUG: 캐시된 트랙 발견: ${track.title}');
        try {
          audioSources.add(_loadedAudioSources[track.id]!);
          print('DEBUG: 캐시된 오디오 소스 추가 성공');
        } catch (e) {
          print('DEBUG: 캐시된 트랙 재사용 중 오류: ${track.title}: $e');
          // 캐시된 트랙에 문제가 있으면 캐시에서 제거하고 다시 로드
          _loadedAudioSources.remove(track.id);
          print('DEBUG: 캐시에서 문제 있는 트랙 제거');
          uncachedTracks.add(track);
        }
      } else {
        uncachedTracks.add(track);
      }
    }

    // 캐시되지 않은 트랙이 있으면 병렬로 매니페스트 가져오기
    if (uncachedTracks.isNotEmpty) {
      print('DEBUG: 캐시되지 않은 트랙 ${uncachedTracks.length}개 처리 시작');

      // 병렬로 매니페스트 가져오기
      final manifestFutures = <Future<Map<String, dynamic>>>[];

      for (final track in uncachedTracks) {
        // 매니페스트가 이미 캐시에 있는지 확인
        if (_manifestCache.containsKey(track.id)) {
          print('DEBUG: 매니페스트 캐시 사용: ${track.title}');
          manifestFutures.add(
            Future.value({
              'track': track,
              'manifest': _manifestCache[track.id],
              'success': true,
            }),
          );
        } else {
          // 매니페스트 가져오기 (최대 2회 재시도)
          manifestFutures.add(_getManifestWithRetry(track));
        }
      }

      // 모든 매니페스트 요청 병렬 처리 후 결과 수집
      final results = await Future.wait(manifestFutures);

      // 매니페스트 결과로 오디오 소스 생성
      for (final result in results) {
        if (result['success'] == true) {
          final track = result['track'] as MusicTrack;
          final manifest = result['manifest'] as StreamManifest;

          try {
            // 오디오 스트림이 없는 경우 처리
            if (manifest.audioOnly.isEmpty) {
              print('DEBUG: 오디오 스트림이 없음 - 트랙: ${track.title}');
              continue;
            }

            final audioStream = manifest.audioOnly.withHighestBitrate();
            if (audioStream == null) {
              print('DEBUG: 적합한 오디오 스트림을 찾을 수 없음 - 트랙: ${track.title}');
              continue;
            }

            // URL이 유효한지 확인
            final urlString = audioStream.url.toString();
            if (urlString.isEmpty) {
              print('DEBUG: URL이 비어있음 - 트랙: ${track.title}');
              continue;
            }

            final uri = Uri.parse(urlString);
            final audioSource = AudioSource.uri(uri, tag: track);

            // 캐시에 저장
            _loadedAudioSources[track.id] = audioSource;
            audioSources.add(audioSource);
            print('DEBUG: 오디오 소스 생성 완료: ${track.title}');
          } catch (e) {
            print('DEBUG: 오디오 소스 생성 중 오류: ${track.title}: $e');
            continue;
          }
        }
      }
    }

    // 로드된 오디오 소스가 없으면 처리 중단
    print('DEBUG: 로드된 오디오 소스 수: ${audioSources.length}');
    if (audioSources.isEmpty) {
      print('DEBUG: 로드된 오디오 소스가 없음, 처리 중단');

      // 이전 재생 상태 복원
      if (wasPlaying) {
        try {
          await runOnUIThread(() async {
            await _musicService.audioPlayer.play();
            print('DEBUG: 이전 재생 상태 복원 (재생)');
            return null;
          });
        } catch (e) {
          print('DEBUG: 재생 상태 복원 중 오류: $e');
        }
      }
      return;
    }

    try {
      print('DEBUG: concatenatingSource에 오디오 소스 삽입 시작');
      // UI 스레드에서 오디오 소스 삽입 실행
      await runOnUIThread(() async {
        await _concatenatingSource!.insertAll(insertIndex, audioSources);
        print('DEBUG: concatenatingSource에 오디오 소스 삽입 완료');
        return null;
      });

      // 이전 재생 상태 복원
      if (wasPlaying) {
        try {
          await runOnUIThread(() async {
            await _musicService.audioPlayer.play();
            print('DEBUG: 이전 재생 상태 복원 (재생)');
            return null;
          });
        } catch (e) {
          print('DEBUG: 재생 상태 복원 중 오류: $e');
        }
      }
    } catch (e) {
      print('DEBUG: 오디오 소스 삽입 중 오류: $e');
      print('DEBUG: 오류 스택 트레이스:');
      print(StackTrace.current);

      // 오류 발생 시에도 이전 재생 상태 복원 시도
      if (wasPlaying) {
        try {
          await runOnUIThread(() async {
            await _musicService.audioPlayer.play();
            print('DEBUG: 오류 후 이전 재생 상태 복원 시도');
            return null;
          });
        } catch (playError) {
          print('DEBUG: 오류 후 재생 상태 복원 중 추가 오류: $playError');
        }
      }
    }
    print('DEBUG: _loadTracksToSource 완료');
  }

  // 매니페스트 가져오기 (재시도 로직 포함)
  Future<Map<String, dynamic>> _getManifestWithRetry(MusicTrack track) async {
    int retryCount = 0;
    const maxRetries = 2;
    StreamManifest? manifest;

    while (retryCount <= maxRetries) {
      try {
        print(
          'DEBUG: 매니페스트 가져오기 시작 - 트랙: ${track.title} (시도: ${retryCount + 1})',
        );
        manifest = await _musicService.getManifest(track.id);

        // 성공하면 캐시에 저장
        _manifestCache[track.id] = manifest;

        return {'track': track, 'manifest': manifest, 'success': true};
      } catch (e) {
        retryCount++;
        print('DEBUG: 매니페스트 가져오기 실패 (시도 $retryCount/$maxRetries): $e');

        if (retryCount <= maxRetries) {
          // 재시도 전 짧은 지연 (지수 백오프)
          await Future.delayed(Duration(milliseconds: 200 * retryCount));
        } else {
          return {'track': track, 'error': e.toString(), 'success': false};
        }
      }
    }

    // 이 코드는 실행되지 않아야 하지만, 컴파일러 경고를 방지하기 위해 추가
    return {'track': track, 'error': 'Unknown error', 'success': false};
  }

  // 인덱스 변경 리스너 설정
  void _setupIndexChangeListener() {
    // 기존 리스너가 있다면 취소 (중복 방지)
    _indexChangeSubscription?.cancel();

    // 새 리스너 설정
    _indexChangeSubscription = _musicService.audioPlayer.currentIndexStream
        .listen((index) {
          if (index == null || _allTracks.isEmpty || _isLoadingMore) return;

          // 현재 인덱스가 전체 로드된 트랙 수의 절반 이상이면 다음 트랙들 미리 로드
          final loadedCount = _concatenatingSource?.children.length ?? 0;
          if (index >= loadedCount - _preloadCount) {
            _loadMoreTracks(loadedCount);
          }
        });

    // 셔플 모드 변경 리스너 설정
    _shuffleModeSubscription?.cancel();
    _shuffleModeSubscription = _musicService
        .audioPlayer
        .shuffleModeEnabledStream
        .listen((shuffleEnabled) {
          // 셔플 모드가 변경되었을 때 처리 로직
          print('Shuffle mode changed: $shuffleEnabled');
          // 셔플 모드 변경 시 특별한 처리가 필요하면 여기에 추가
        });
  }

  // 추가 트랙 로드
  Future<void> _loadMoreTracks(int loadedCount) async {
    if (_isLoadingMore || _concatenatingSource == null) return;
    _isLoadingMore = true;

    try {
      if (loadedCount >= _allTracks.length) {
        _isLoadingMore = false;
        return; // 모든 트랙이 이미 로드됨
      }

      // 다음 preloadCount 개의 트랙 로드
      final nextTracksToLoad = <MusicTrack>[];
      final endIndex = (loadedCount + _preloadCount).clamp(
        0,
        _allTracks.length,
      );

      for (int i = loadedCount; i < endIndex; i++) {
        nextTracksToLoad.add(_allTracks[i]);
      }

      await _loadTracksToSource(nextTracksToLoad, loadedCount);
    } catch (e) {
      print('Error loading more tracks: $e');
    } finally {
      _isLoadingMore = false;
    }
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
  bool _isSeeking = false; // 버퍼링 락 추가
  StreamSubscription? _currentIndexSubscription;

  CurrentTrackNotifier(
    this._musicService,
    this._preferencesService,
    this._searchResults,
  ) : super(null) {
    _restoreLastPlayedTrack();

    // 현재 재생 중인 트랙 상태 업데이트를 위한 리스너 추가
    _setupCurrentIndexListener();
  }

  void _setupCurrentIndexListener() {
    // 기존 리스너 취소
    _currentIndexSubscription?.cancel();
    print('DEBUG: CurrentTrackNotifier - _setupCurrentIndexListener 시작');

    // 새 리스너 설정
    _currentIndexSubscription = _musicService.audioPlayer.currentIndexStream.listen((
      index,
    ) {
      print('DEBUG: CurrentTrackNotifier - 인덱스 변경 감지: $index');
      if (index != null) {
        final currentSource = _musicService.audioPlayer.audioSource;
        print(
          'DEBUG: CurrentTrackNotifier - 현재 오디오 소스: ${currentSource?.runtimeType}',
        );
        if (currentSource is ConcatenatingAudioSource &&
            index < currentSource.children.length) {
          final source = currentSource.children[index];
          print('DEBUG: CurrentTrackNotifier - 소스 타입: ${source.runtimeType}');
          if (source is UriAudioSource && source.tag is MusicTrack) {
            final track = source.tag as MusicTrack;
            print(
              'DEBUG: CurrentTrackNotifier - 트랙 정보 업데이트: ${track.title} (ID: ${track.id})',
            );
            state = track;
          } else {
            print(
              'DEBUG: CurrentTrackNotifier - 소스가 UriAudioSource가 아니거나 태그가 MusicTrack이 아님',
            );
          }
        } else {
          print('DEBUG: CurrentTrackNotifier - 유효한 오디오 소스가 아니거나 인덱스가 범위를 벗어남');
        }
      } else {
        print('DEBUG: CurrentTrackNotifier - 인덱스가 null임');
      }
    });
    print('DEBUG: CurrentTrackNotifier - _setupCurrentIndexListener 완료');
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
    if (_isSeeking) return;
    _isSeeking = true;
    try {
      // 현재 오디오 소스 확인
      final currentSource = _musicService.audioPlayer.audioSource;
      if (currentSource == null) {
        _isSeeking = false;
        return;
      }

      // 다음 트랙으로 이동 전에 현재 재생 상태 저장
      final wasPlaying = _musicService.audioPlayer.playing;

      // 다음 트랙으로 이동
      await _musicService.audioPlayer.seekToNext();
      final index = _musicService.audioPlayer.currentIndex;

      // 유효한 인덱스인지 확인
      if (index != null &&
          currentSource is ConcatenatingAudioSource &&
          index < currentSource.children.length) {
        final source = currentSource.children[index];
        if (source is UriAudioSource && source.tag is MusicTrack) {
          final track = source.tag as MusicTrack;
          print(
            'Playing track: ${track.title} by ${track.artist} (id: ${track.id})',
          );

          // 상태 업데이트
          state = track;

          // 마지막 재생 트랙 저장
          _preferencesService.setLastPlayedTrack(track.id);

          // 트랙 로딩 중 일시적으로 일시정지 후 로딩 완료 시 재생 재개
          if (wasPlaying) {
            // 짧은 지연 후 재생 상태 확인 및 재개
            await Future.delayed(const Duration(milliseconds: 100));
            if (!_musicService.audioPlayer.playing) {
              await _musicService.audioPlayer.play();
            }
          }
        }
      }
    } catch (e) {
      print('Error during playNext: $e');
      // 오류 발생 시 재생 중지
      await _musicService.audioPlayer.stop();
    } finally {
      _isSeeking = false;
    }
  }

  Future<void> playPrevious() async {
    if (_isSeeking) return;
    _isSeeking = true;
    try {
      // 현재 오디오 소스 확인
      final currentSource = _musicService.audioPlayer.audioSource;
      if (currentSource == null) {
        _isSeeking = false;
        return;
      }

      // 이전 트랙으로 이동 전에 현재 재생 상태 저장
      final wasPlaying = _musicService.audioPlayer.playing;

      // 이전 트랙으로 이동
      await _musicService.audioPlayer.seekToPrevious();
      final index = _musicService.audioPlayer.currentIndex;

      // 유효한 인덱스인지 확인
      if (index != null &&
          currentSource is ConcatenatingAudioSource &&
          index < currentSource.children.length) {
        final source = currentSource.children[index];
        if (source is UriAudioSource && source.tag is MusicTrack) {
          final track = source.tag as MusicTrack;
          print(
            'Playing track: ${track.title} by ${track.artist} (id: ${track.id})',
          );

          // 상태 업데이트
          state = track;

          // 마지막 재생 트랙 저장
          _preferencesService.setLastPlayedTrack(track.id);

          // 트랙 로딩 중 일시적으로 일시정지 후 로딩 완료 시 재생 재개
          if (wasPlaying) {
            // 짧은 지연 후 재생 상태 확인 및 재개
            await Future.delayed(const Duration(milliseconds: 100));
            if (!_musicService.audioPlayer.playing) {
              await _musicService.audioPlayer.play();
            }
          }
        }
      }
    } catch (e) {
      print('Error during playPrevious: $e');
      // 오류 발생 시 재생 중지
      await _musicService.audioPlayer.stop();
    } finally {
      _isSeeking = false;
    }
  }

  @override
  void dispose() {
    _currentIndexSubscription?.cancel();
    super.dispose();
  }
}
