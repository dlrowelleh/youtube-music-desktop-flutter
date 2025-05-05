import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/music_track.dart';
import '../providers/music_provider.dart';
import '../providers/preferences_provider.dart';

class EnhancedMusicPlayer extends ConsumerStatefulWidget {
  const EnhancedMusicPlayer({super.key});

  @override
  ConsumerState<EnhancedMusicPlayer> createState() =>
      _EnhancedMusicPlayerState();
}

class _EnhancedMusicPlayerState extends ConsumerState<EnhancedMusicPlayer> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late final AudioPlayer _audioPlayer;
  late final TextEditingController _volumeController;
  late final FocusNode _volumeFocusNode;
  late final FocusNode _sliderFocusNode;
  bool _isControlPressed = false;
  bool _isBuffering = false;
  String? _playbackError; // Moved to class field

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    _volumeController = TextEditingController();
    _volumeController.addListener(_handleVolumeChange);
    _volumeFocusNode = FocusNode();
    _sliderFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _volumeFocusNode.dispose();
    _sliderFocusNode.dispose();
    super.dispose();
  }

  void _handleVolumeChange() {
    final value = double.tryParse(_volumeController.text);
    if (value != null && value >= 0 && value <= 1) {
      ref.read(preferencesProvider.notifier).setVolume(value);
      _audioPlayer.setVolume(value);
    }
  }

  void _setupAudioPlayer() {
    _audioPlayer = ref.read(musicServiceProvider).audioPlayer;
    final preferences = ref.read(preferencesProvider);
    _audioPlayer.setVolume(preferences.volume);
    _audioPlayer.setShuffleModeEnabled(preferences.shuffleEnabled);
    _audioPlayer.setLoopMode(
      preferences.repeatEnabled ? LoopMode.all : LoopMode.off,
    );
    Future(() {
      // 플레이어 상태 변경 리스너 개선
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            // 버퍼링 상태 감지 로직 개선
            _isBuffering =
                state.processingState == ProcessingState.buffering ||
                state.processingState == ProcessingState.loading;

            // 트랙 전환 중에도 버퍼링 상태로 처리
            if (state.processingState == ProcessingState.ready &&
                _position == Duration.zero &&
                _duration > Duration.zero) {
              _isBuffering = true;
              // 짧은 지연 후 버퍼링 상태 해제 (UI 업데이트 보장)
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    _isBuffering = false;
                  });
                }
              });
            }

            // 에러 상태 처리
            if (state.processingState == ProcessingState.idle &&
                state.playing) {
              _playbackError = "Playback error occurred.";
            } else {
              _playbackError = null;
            }
          });
        }
      });

      // 위치 스트림 리스너
      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
            // 위치가 업데이트되면 버퍼링이 아님을 확인
            if (position > Duration.zero && _isBuffering) {
              _isBuffering = false;
            }
          });
        }
      });

      // 재생 시간 스트림 리스너
      _audioPlayer.durationStream.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration ?? Duration.zero;
          });
        }
      });

      // 트랙 인덱스 변경 리스너
      _audioPlayer.currentIndexStream.listen((index) {
        if (index != null && mounted) {
          // 트랙이 변경되면 일시적으로 버퍼링 상태로 설정
          setState(() {
            _isBuffering = true;
            _position = Duration.zero; // 위치 초기화
          });

          final currentTrack = ref.read(currentTrackProvider);
          if (currentTrack != null) {
            ref
                .read(preferencesProvider.notifier)
                .setLastPlayedTrack(currentTrack.id);
          }
        }
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(currentTrackProvider);
    final audioPlayer = ref.read(musicServiceProvider).audioPlayer;
    final isPlaying = audioPlayer.playing;
    // Removed local declaration of _playbackError
    if (currentTrack == null) return const SizedBox.shrink();
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (_isBuffering) const Center(child: CircularProgressIndicator()),
          if (_playbackError != null)
            Center(
              child: Text(
                _playbackError!,
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Column(
            children: [
              // Progress bar
              SliderTheme(
                data: SliderThemeData(
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  trackHeight: 4,
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Colors.grey[800],
                  thumbColor: Theme.of(context).colorScheme.primary,
                ),
                child: Slider(
                  value: _position.inSeconds.toDouble(),
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (value) {
                    audioPlayer.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),
              // Time indicators
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position)),
                    Text(_formatDuration(_duration)),
                  ],
                ),
              ),
              // Player controls and track info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Track info
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Image.network(
                              currentTrack.thumbnailUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    currentTrack.title,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    currentTrack.artist,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Playback controls
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Consumer(
                              builder: (context, ref, _) {
                                final prefs = ref.watch(preferencesProvider);
                                return IconButton(
                                  icon: Icon(
                                    prefs.shuffleEnabled
                                        ? Icons.shuffle_on_outlined
                                        : Icons.shuffle,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(preferencesProvider.notifier)
                                        .toggleShuffle();
                                    _audioPlayer.setShuffleModeEnabled(
                                      !prefs.shuffleEnabled,
                                    );
                                    // Fisher-Yates shuffle and play shuffled playlist in order
                                    final playlistTracks = ref.read(
                                      playlistTracksProvider,
                                    );
                                    final playlistNotifier = ref.read(
                                      playlistTracksProvider.notifier,
                                    );
                                    if (playlistTracks.isNotEmpty) {
                                      if (!prefs.shuffleEnabled) {
                                        // Shuffle is being turned ON, use Fisher-Yates shuffle
                                        List<MusicTrack> shuffled =
                                            List<MusicTrack>.from(
                                              playlistTracks,
                                            );
                                        for (
                                          int i = shuffled.length - 1;
                                          i > 0;
                                          i--
                                        ) {
                                          int j =
                                              (DateTime.now()
                                                      .microsecondsSinceEpoch +
                                                  i) %
                                              (i + 1);
                                          final temp = shuffled[i];
                                          shuffled[i] = shuffled[j];
                                          shuffled[j] = temp;
                                        }
                                        // Play shuffled playlist in order
                                        playlistNotifier.playPlaylistTracks(
                                          shuffled,
                                          0,
                                        );
                                        _audioPlayer.setShuffleModeEnabled(
                                          false,
                                        );
                                        // Update current track state for UI and playback
                                        ref
                                            .read(currentTrackProvider.notifier)
                                            .state = shuffled.isNotEmpty
                                                ? shuffled.first
                                                : null;
                                      } else {
                                        // Shuffle is being turned OFF, reload in original order
                                        playlistNotifier.playPlaylistTracks(
                                          playlistTracks,
                                          0,
                                        );
                                        _audioPlayer.setShuffleModeEnabled(
                                          false,
                                        );
                                        ref
                                            .read(currentTrackProvider.notifier)
                                            .state = playlistTracks.isNotEmpty
                                                ? playlistTracks.first
                                                : null;
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              onPressed:
                                  _isBuffering
                                      ? null
                                      : () =>
                                          ref
                                              .read(
                                                currentTrackProvider.notifier,
                                              )
                                              .playPrevious(),
                            ),
                            IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                              ),
                              onPressed:
                                  _isBuffering
                                      ? null
                                      : () {
                                        if (isPlaying) {
                                          _audioPlayer.pause();
                                        } else {
                                          _audioPlayer.play();
                                        }
                                      },
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next),
                              onPressed:
                                  _isBuffering
                                      ? null
                                      : () =>
                                          ref
                                              .read(
                                                currentTrackProvider.notifier,
                                              )
                                              .playNext(),
                            ),
                            Consumer(
                              builder: (context, ref, _) {
                                final prefs = ref.watch(preferencesProvider);
                                return IconButton(
                                  icon: Icon(
                                    prefs.repeatEnabled
                                        ? Icons.repeat_on_outlined
                                        : Icons.repeat,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(preferencesProvider.notifier)
                                        .toggleRepeat();
                                    _audioPlayer.setLoopMode(
                                      prefs.repeatEnabled
                                          ? LoopMode.off
                                          : LoopMode.all,
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Volume control
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Consumer(
                              builder: (context, ref, _) {
                                final prefs = ref.watch(preferencesProvider);
                                return Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        prefs.volume == 0
                                            ? Icons.volume_off
                                            : Icons.volume_up,
                                      ),
                                      onPressed: () {
                                        final newVolume =
                                            prefs.volume > 0 ? 0.0 : 1.0;
                                        ref
                                            .read(preferencesProvider.notifier)
                                            .setVolume(newVolume);
                                        _audioPlayer.setVolume(newVolume);
                                      },
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: RawKeyboardListener(
                                        focusNode: _sliderFocusNode,
                                        onKey: (event) {
                                          if (event is RawKeyDownEvent) {
                                            if (event.logicalKey ==
                                                    LogicalKeyboardKey
                                                        .controlLeft ||
                                                event.logicalKey ==
                                                    LogicalKeyboardKey
                                                        .controlRight) {
                                              setState(
                                                () => _isControlPressed = true,
                                              );
                                            } else if (_isControlPressed &&
                                                event.logicalKey ==
                                                    LogicalKeyboardKey.keyV) {
                                              Clipboard.getData(
                                                'text/plain',
                                              ).then((value) {
                                                if (value != null) {
                                                  final pastedValue =
                                                      double.tryParse(
                                                        value.text ?? '',
                                                      );
                                                  if (pastedValue != null &&
                                                      pastedValue >= 0 &&
                                                      pastedValue <= 1) {
                                                    ref
                                                        .read(
                                                          preferencesProvider
                                                              .notifier,
                                                        )
                                                        .setVolume(pastedValue);
                                                    _audioPlayer.setVolume(
                                                      pastedValue,
                                                    );
                                                  }
                                                }
                                              });
                                            }
                                          } else if (event is RawKeyUpEvent &&
                                              (event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .controlLeft ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .controlRight)) {
                                            setState(
                                              () => _isControlPressed = false,
                                            );
                                          }
                                        },
                                        child: Slider(
                                          value: prefs.volume,
                                          onChanged: (value) {
                                            ref
                                                .read(
                                                  preferencesProvider.notifier,
                                                )
                                                .setVolume(value);
                                            _audioPlayer.setVolume(value);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
