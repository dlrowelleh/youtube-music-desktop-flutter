import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import '../providers/music_provider.dart';
import '../providers/preferences_provider.dart';
import '../models/music_track.dart'; // MusicTrack 모델 import

class FullScreenPlayerScreen extends ConsumerStatefulWidget {
  const FullScreenPlayerScreen({super.key});

  @override
  ConsumerState<FullScreenPlayerScreen> createState() =>
      _FullScreenPlayerScreenState();
}

class _FullScreenPlayerScreenState
    extends ConsumerState<FullScreenPlayerScreen> {
  late final media_kit.Player _audioPlayer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late final TextEditingController _volumeController;
  late final FocusNode _volumeFocusNode;
  late final FocusNode _sliderFocusNode;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = ref.read(musicServiceProvider).audioPlayer;
    _volumeController = TextEditingController();
    _volumeFocusNode = FocusNode();
    _sliderFocusNode = FocusNode();
    _loadInitialPlayerPreferences();
    _setupAudioPlayerListeners();
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _volumeFocusNode.dispose();
    _sliderFocusNode.dispose();
    super.dispose();
  }

  void _loadInitialPlayerPreferences() {
    final preferences = ref.read(preferencesProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (!Platform.isAndroid) {
          // Android가 아닐 때만 볼륨 설정
          _audioPlayer.setVolume(preferences.volume * 100);
        }
        _audioPlayer.setShuffle(preferences.shuffleEnabled);
        _audioPlayer.setPlaylistMode(
          preferences.repeatEnabled
              ? media_kit.PlaylistMode.loop
              : media_kit.PlaylistMode.none,
        );
        _volumeController.text = (preferences.volume * 100).toStringAsFixed(0);
      }
    });
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.stream.playing.listen((playing) {
      if (mounted) setState(() {});
    });

    _audioPlayer.stream.buffering.listen((isBuffering) {
      if (mounted) {
        setState(() {
          _isBuffering = isBuffering;
        });
      }
    });

    _audioPlayer.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
          if (_position > Duration.zero && _isBuffering) {
            _isBuffering = false;
          }
        });
      }
    });

    _audioPlayer.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.stream.playlist.listen((playlist) {
      if (mounted && playlist.medias.isNotEmpty) {
        final currentMedia = playlist.medias[playlist.index];
        final track = currentMedia.extras?['music_track'] as MusicTrack?;
        if (track != null) {
          ref.read(currentTrackProvider.notifier).updateTrackInfo(track);
        }
        setState(() {
          _isBuffering = true;
          _position = Duration.zero;
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _audioPlayer.state.playing) {
            if (!_audioPlayer.state.buffering) {
              setState(() => _isBuffering = false);
            }
          } else if (mounted) {
            setState(() => _isBuffering = false);
          }
        });
      }
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
    final isPlaying = _audioPlayer.state.playing;
    final prefs = ref.watch(preferencesProvider);
    final bool isAndroid = Platform.isAndroid;

    if (currentTrack == null) {
      // 현재 트랙이 없으면 이전 화면으로 돌아가거나 빈 화면 표시
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text("재생 중인 곡이 없습니다.")),
      );
    }

    final currentVolumeForTextField = (prefs.volume * 100).toStringAsFixed(0);
    if (_volumeController.text != currentVolumeForTextField) {
      _volumeController.text = currentVolumeForTextField;
      _volumeController.selection = TextSelection.fromPosition(
        TextPosition(offset: _volumeController.text.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(
                (Theme.of(context).colorScheme.secondaryContainer.r * 255)
                    .round(),
                (Theme.of(context).colorScheme.secondaryContainer.g * 255)
                    .round(),
                (Theme.of(context).colorScheme.secondaryContainer.b * 255)
                    .round(),
                0.7,
              ),
              Theme.of(context).colorScheme.surface,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 앨범 아트 및 곡 정보
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.network(
                        currentTrack.thumbnailUrl,
                        width: MediaQuery.of(context).size.width * 0.7,
                        height: MediaQuery.of(context).size.width * 0.7,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              width: MediaQuery.of(context).size.width * 0.7,
                              height: MediaQuery.of(context).size.width * 0.7,
                              color: Colors.grey[300],
                              child: Icon(
                                Icons.music_note,
                                size: 100,
                                color: Colors.grey[600],
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      currentTrack.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentTrack.artist,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 재생 진행 슬라이더 및 시간
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      inactiveTrackColor: Color.fromRGBO(
                        (Theme.of(context).colorScheme.onSurface.r * 255)
                            .round(),
                        (Theme.of(context).colorScheme.onSurface.g * 255)
                            .round(),
                        (Theme.of(context).colorScheme.onSurface.b * 255)
                            .round(),
                        0.3,
                      ),
                      thumbColor: Theme.of(context).colorScheme.primary,
                      overlayColor: Color.fromRGBO(
                        (Theme.of(context).colorScheme.primary.r * 255).round(),
                        (Theme.of(context).colorScheme.primary.g * 255).round(),
                        (Theme.of(context).colorScheme.primary.b * 255).round(),
                        0.2,
                      ),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8.0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16.0,
                      ),
                    ),
                    child: Slider(
                      value: _position.inSeconds.toDouble().clamp(
                        0.0,
                        _duration.inSeconds.toDouble() > 0
                            ? _duration.inSeconds.toDouble()
                            : 1.0, // max가 0보다 커야 함
                      ),
                      max:
                          _duration.inSeconds.toDouble() > 0
                              ? _duration.inSeconds.toDouble()
                              : 1.0,
                      onChanged: (value) {
                        if (_duration > Duration.zero) {
                          _audioPlayer.seek(Duration(seconds: value.toInt()));
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                ],
              ),
              const SizedBox(height: 20),

              // 컨트롤 버튼 (재생/일시정지, 이전, 다음, 셔플, 반복)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    iconSize: 28,
                    icon: Icon(
                      prefs.shuffleEnabled
                          ? Icons.shuffle_on_outlined
                          : Icons.shuffle,
                      color:
                          prefs.shuffleEnabled
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () {
                      final newShuffleState = !prefs.shuffleEnabled;
                      ref.read(preferencesProvider.notifier).toggleShuffle();
                      _audioPlayer.setShuffle(newShuffleState);
                    },
                  ),
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_previous),
                    onPressed:
                        _isBuffering
                            ? null
                            : () =>
                                ref
                                    .read(currentTrackProvider.notifier)
                                    .playPrevious(),
                  ),
                  IconButton(
                    iconSize: 50,
                    icon:
                        _isBuffering
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: const CircularProgressIndicator(
                                strokeWidth: 3,
                              ),
                            )
                            : Icon(
                              isPlaying
                                  ? Icons.pause_circle_filled_outlined
                                  : Icons.play_circle_fill_outlined,
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
                    iconSize: 36,
                    icon: const Icon(Icons.skip_next),
                    onPressed:
                        _isBuffering
                            ? null
                            : () =>
                                ref
                                    .read(currentTrackProvider.notifier)
                                    .playNext(),
                  ),
                  IconButton(
                    iconSize: 28,
                    icon: Icon(
                      prefs.repeatEnabled
                          ? Icons.repeat_on_outlined
                          : Icons.repeat,
                      color:
                          prefs.repeatEnabled
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () {
                      final newRepeatState = !prefs.repeatEnabled;
                      ref.read(preferencesProvider.notifier).toggleRepeat();
                      _audioPlayer.setPlaylistMode(
                        newRepeatState
                            ? media_kit.PlaylistMode.loop
                            : media_kit.PlaylistMode.none,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 볼륨 컨트롤 (Android에서는 숨김, EnhancedMusicPlayer와 유사하게)
              if (!isAndroid)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_down),
                    Expanded(
                      child: Slider(
                        value: prefs.volume * 100,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: '${(prefs.volume * 100).round()}%',
                        onChanged: (value) {
                          final doubleVolume = value / 100.0;
                          ref
                              .read(preferencesProvider.notifier)
                              .setVolume(doubleVolume);
                          // Android에서는 setVolume 호출 안 함
                          if (!Platform.isAndroid) {
                            _audioPlayer.setVolume(value);
                          }
                        },
                      ),
                    ),
                    Icon(Icons.volume_up),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _volumeController,
                        focusNode: _volumeFocusNode,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final num = int.tryParse(newValue.text);
                            if (num != null && num >= 0 && num <= 100) {
                              return newValue;
                            }
                            if (newValue.text.isEmpty) {
                              return newValue;
                            }
                            if (num == null) {
                              return oldValue;
                            }
                            if (num < 0) {
                              return const TextEditingValue(
                                text: '0',
                                selection: TextSelection.collapsed(offset: 1),
                              );
                            }
                            if (num > 100) {
                              return const TextEditingValue(
                                text: '100',
                                selection: TextSelection.collapsed(offset: 3),
                              );
                            }
                            return oldValue;
                          }),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Vol',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        textAlign: TextAlign.center,
                        onChanged: (text) {
                          final value = int.tryParse(text);
                          if (value != null && value >= 0 && value <= 100) {
                            final doubleVolume = value / 100.0;
                            if (prefs.volume != doubleVolume) {
                              ref
                                  .read(preferencesProvider.notifier)
                                  .setVolume(doubleVolume);
                              // Android에서는 setVolume 호출 안 함
                              if (!Platform.isAndroid) {
                                _audioPlayer.setVolume(value.toDouble());
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              if (isAndroid) const SizedBox(height: 20), // 안드로이드 하단 여백
            ],
          ),
        ),
      ),
    );
  }
}
