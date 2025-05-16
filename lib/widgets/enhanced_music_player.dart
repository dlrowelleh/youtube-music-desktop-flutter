import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
// import 'package:media_kit_video/media_kit_video.dart'; // 현재 비디오 컨트롤러 사용 안함
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
  late final Player _player;
  // late final TextEditingController _volumeController; // Slider로 대체
  // late final FocusNode _volumeFocusNode; // Slider로 대체
  late final FocusNode _sliderFocusNode;
  bool _isBuffering = false;
  String? _playbackError;

  @override
  void initState() {
    super.initState();
    _setupPlayer();
    // _volumeController = TextEditingController(); // Slider로 대체
    // _volumeController.addListener(_handleVolumeChange); // Slider로 대체
    // _volumeFocusNode = FocusNode(); // Slider로 대체
    _sliderFocusNode = FocusNode();
  }

  @override
  void dispose() {
    // _volumeController.dispose(); // Slider로 대체
    // _volumeFocusNode.dispose(); // Slider로 대체
    _sliderFocusNode.dispose();
    super.dispose();
  }

  // void _handleVolumeChange() { // Slider로 대체되므로 주석 처리 또는 삭제
  //   final value = double.tryParse(_volumeController.text);
  //   if (value != null && value >= 0 && value <= 1) {
  //     ref.read(preferencesProvider.notifier).setVolume(value);
  //     _player.setVolume(value * 100);
  //   }
  // }

  void _setupPlayer() {
    _player = ref.read(musicServiceProvider).player;
    final preferences = ref.read(preferencesProvider);
    _player.setVolume(preferences.volume * 100);
    _player.setShuffle(preferences.shuffleEnabled);
    _player.setPlaylistMode(
      preferences.repeatEnabled ? PlaylistMode.loop : PlaylistMode.none,
    );

    Future.microtask(() {
      _player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _playbackError = null;
          });
        }
      });

      _player.stream.buffering.listen((isBuffering) {
        if (mounted) {
          setState(() {
            _isBuffering = isBuffering;
          });
        }
      });

      _player.stream.error.listen((error) {
        if (mounted && error != null) {
          setState(() {
            _playbackError = error;
            _isBuffering = false;
          });
        }
      });

      _player.stream.position.listen((position) {
        if (mounted) {
          setState(() {
            _position = position ?? Duration.zero;
          });
        }
      });

      _player.stream.duration.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration ?? Duration.zero;
          });
        }
      });

      _player.stream.playlist.listen((playlist) {
        final currentIndex = _player.state.playlist.index;
        if (currentIndex != -1 && mounted) {
          setState(() {
            _isBuffering = true;
            _position = Duration.zero;
            _duration = Duration.zero;
          });

          MusicTrack? currentTrackFromPlaylist;
          if (playlist.medias.isNotEmpty &&
              currentIndex < playlist.medias.length) {
            final media = playlist.medias[currentIndex];
            if (media.extras != null && media.extras!['track'] is MusicTrack) {
              currentTrackFromPlaylist = media.extras!['track'] as MusicTrack?;
            }
          } else {
            currentTrackFromPlaylist = null;
          }

          if (currentTrackFromPlaylist != null) {
            ref
                .read(currentTrackProvider.notifier)
                .setCurrentTrack(currentTrackFromPlaylist);
            ref
                .read(preferencesProvider.notifier)
                .setLastPlayedTrack(currentTrackFromPlaylist.id);
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
    final preferences = ref.watch(preferencesProvider); // preferences watch
    final isPlaying = _player.state.playing;

    if (currentTrack == null) return const SizedBox.shrink();

    final double sliderMax =
        _duration.inSeconds.toDouble() > 0
            ? _duration.inSeconds.toDouble()
            : 0.0;
    final double sliderValue = (_position.inSeconds.toDouble()).clamp(
      0.0,
      sliderMax,
    );

    return Container(
      height: 150, // 컨트롤 추가로 높이 증가
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
          if (_isBuffering && !_player.state.playing)
            const Center(child: CircularProgressIndicator()),
          if (_playbackError != null)
            Center(
              child: Text(
                _playbackError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Padding(
            // 전체 Column에 Padding 추가
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    trackHeight: 3, // 높이 약간 줄임
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Colors.grey[800],
                    thumbColor: Theme.of(context).colorScheme.primary,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: sliderValue,
                    max: sliderMax,
                    onChanged: (value) {
                      _player.seek(Duration(seconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3, // 곡 정보 영역 비율 조정
                        child: Row(
                          children: [
                            if (currentTrack.thumbnailUrl.isNotEmpty)
                              Image.network(
                                currentTrack.thumbnailUrl,
                                width: 50, // 크기 약간 줄임
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        const Icon(Icons.music_note, size: 50),
                              )
                            else
                              const Icon(Icons.music_note, size: 50),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    currentTrack.title,
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.titleSmall, // 폰트 크기 조정
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    currentTrack.artist,
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.bodySmall, // 폰트 크기 조정
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 4, // 컨트롤 영역 비율 조정
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 셔플 버튼
                            IconButton(
                              icon: Icon(
                                preferences.shuffleEnabled
                                    ? Icons.shuffle_on_outlined
                                    : Icons.shuffle,
                                color:
                                    preferences.shuffleEnabled
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                              ),
                              iconSize: 24,
                              onPressed: () {
                                ref
                                    .read(currentTrackProvider.notifier)
                                    .toggleShuffle();
                              },
                            ),
                            // 반복 버튼
                            IconButton(
                              icon: Icon(
                                preferences.repeatEnabled
                                    ? Icons.repeat_one_on_outlined
                                    : Icons.repeat,
                                color:
                                    preferences.repeatEnabled
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                              ),
                              iconSize: 24,
                              onPressed: () {
                                ref
                                    .read(currentTrackProvider.notifier)
                                    .toggleRepeat();
                              },
                            ),
                            const SizedBox(width: 8), // 컨트롤 간 간격
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              iconSize: 28, // 아이콘 크기 조정
                              onPressed: () async {
                                await _player.previous();
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_circle_filled_outlined
                                    : Icons.play_circle_filled_outlined,
                              ),
                              iconSize: 40, // 아이콘 크기 조정
                              onPressed: () async {
                                await _player.playOrPause();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next),
                              iconSize: 28, // 아이콘 크기 조정
                              onPressed: () async {
                                await _player.next();
                              },
                            ),
                            const SizedBox(width: 8),
                            // 볼륨 아이콘 (클릭 시 음소거 토글 또는 슬라이더 표시 - 여기서는 아이콘만)
                            Icon(
                              preferences.volume == 0
                                  ? Icons.volume_off
                                  : preferences.volume < 0.5
                                  ? Icons.volume_down
                                  : Icons.volume_up,
                              size: 24,
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2.0,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8.0,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16.0,
                                  ),
                                ),
                                child: Slider(
                                  value: preferences.volume,
                                  min: 0.0,
                                  max: 1.0,
                                  onChanged: (value) {
                                    ref
                                        .read(preferencesProvider.notifier)
                                        .setVolume(value);
                                    _player.setVolume(value * 100);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
