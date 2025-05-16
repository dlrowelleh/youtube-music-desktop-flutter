import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import '../providers/music_provider.dart';
import '../providers/preferences_provider.dart';
import '../screens/full_screen_player_screen.dart';

class EnhancedMusicPlayer extends ConsumerStatefulWidget {
  const EnhancedMusicPlayer({super.key});

  @override
  ConsumerState<EnhancedMusicPlayer> createState() =>
      _EnhancedMusicPlayerState();
}

class _EnhancedMusicPlayerState extends ConsumerState<EnhancedMusicPlayer> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late final media_kit.Player _audioPlayer;
  late final TextEditingController _volumeController;
  late final FocusNode _volumeFocusNode;
  late final FocusNode _sliderFocusNode;
  bool _isBuffering = false;
  String? _playbackError;

  @override
  void initState() {
    super.initState();
    _audioPlayer = ref.read(musicServiceProvider).audioPlayer;
    _setupAudioPlayerListeners();
    _volumeController = TextEditingController();
    _volumeFocusNode = FocusNode();
    _sliderFocusNode = FocusNode();
    _loadInitialPlayerPreferences();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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

    _audioPlayer.stream.error.listen((errorMsg) {
      if (mounted) {
        setState(() {
          _playbackError = "Playback error: $errorMsg";
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
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(currentTrackProvider);
    final isPlaying = _audioPlayer.state.playing;
    final prefs = ref.watch(preferencesProvider);
    final bool isAndroid = Platform.isAndroid;

    if (currentTrack == null) return const SizedBox.shrink();

    final double playerHeight = isAndroid ? 80.0 : 120.0;

    return Container(
      height: playerHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (!_isBuffering && _playbackError == null)
            Column(
              children: [
                if (!isAndroid)
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
                      value: _position.inSeconds.toDouble().clamp(
                        0.0,
                        _duration.inSeconds.toDouble(),
                      ),
                      max: _duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        _audioPlayer.seek(Duration(seconds: value.toInt()));
                      },
                    ),
                  ),
                if (!isAndroid)
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const FullScreenPlayerScreen(),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Image.network(
                                  currentTrack.thumbnailUrl,
                                  width: isAndroid ? 50 : 60,
                                  height: isAndroid ? 50 : 60,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) => Icon(
                                        Icons.music_note,
                                        size: isAndroid ? 50 : 60,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentTrack.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize:
                                              isAndroid
                                                  ? 12
                                                  : Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.fontSize ??
                                                      16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      Text(
                                        currentTrack.artist,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(
                                          fontSize:
                                              isAndroid
                                                  ? 10
                                                  : Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.fontSize ??
                                                      14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: isAndroid ? 2 : 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isAndroid)
                                IconButton(
                                  iconSize: 24.0,
                                  icon: Icon(
                                    prefs.shuffleEnabled
                                        ? Icons.shuffle_on_outlined
                                        : Icons.shuffle,
                                  ),
                                  onPressed: () {
                                    final newShuffleState =
                                        !prefs.shuffleEnabled;
                                    ref
                                        .read(preferencesProvider.notifier)
                                        .toggleShuffle();
                                    _audioPlayer.setShuffle(newShuffleState);
                                  },
                                ),
                              IconButton(
                                iconSize: isAndroid ? 24.0 : 28.0,
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
                                iconSize: isAndroid ? 32.0 : 36.0,
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
                                iconSize: isAndroid ? 24.0 : 28.0,
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
                              if (!isAndroid)
                                IconButton(
                                  iconSize: 24.0,
                                  icon: Icon(
                                    prefs.repeatEnabled
                                        ? Icons.repeat_on_outlined
                                        : Icons.repeat,
                                  ),
                                  onPressed: () {
                                    final newRepeatState = !prefs.repeatEnabled;
                                    ref
                                        .read(preferencesProvider.notifier)
                                        .toggleRepeat();
                                    _audioPlayer.setPlaylistMode(
                                      newRepeatState
                                          ? media_kit.PlaylistMode.loop
                                          : media_kit.PlaylistMode.none,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        if (!isAndroid)
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Consumer(
                                  builder: (context, ref, _) {
                                    final currentVolumeForTextField =
                                        (prefs.volume * 100).toStringAsFixed(0);
                                    if (_volumeController.text !=
                                        currentVolumeForTextField) {
                                      _volumeController.text =
                                          currentVolumeForTextField;
                                      _volumeController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset:
                                                  _volumeController.text.length,
                                            ),
                                          );
                                    }
                                    final displayVolume =
                                        (prefs.volume * 100).round();

                                    return Row(
                                      children: [
                                        IconButton(
                                          iconSize: 24.0,
                                          icon: Icon(
                                            displayVolume == 0
                                                ? Icons.volume_off
                                                : displayVolume < 50
                                                ? Icons.volume_down
                                                : Icons.volume_up,
                                          ),
                                          onPressed: () {
                                            final currentVolume = prefs.volume;
                                            final newVolumePercent =
                                                currentVolume > 0 ? 0.0 : 1.0;
                                            ref
                                                .read(
                                                  preferencesProvider.notifier,
                                                )
                                                .setVolume(newVolumePercent);
                                            if (!Platform.isAndroid) {
                                              _audioPlayer.setVolume(
                                                newVolumePercent * 100,
                                              );
                                            }
                                          },
                                        ),
                                        SizedBox(
                                          width: 100,
                                          child: Focus(
                                            focusNode: _sliderFocusNode,
                                            child: Slider(
                                              value: prefs.volume * 100,
                                              min: 0,
                                              max: 100,
                                              divisions: 100,
                                              label: '$displayVolume%',
                                              onChanged: (value) {
                                                final doubleVolume =
                                                    value / 100.0;
                                                ref
                                                    .read(
                                                      preferencesProvider
                                                          .notifier,
                                                    )
                                                    .setVolume(doubleVolume);
                                                if (!Platform.isAndroid) {
                                                  _audioPlayer.setVolume(value);
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 50,
                                          child: TextField(
                                            controller: _volumeController,
                                            focusNode: _volumeFocusNode,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: <
                                              TextInputFormatter
                                            >[
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                3,
                                              ),
                                              TextInputFormatter.withFunction((
                                                oldValue,
                                                newValue,
                                              ) {
                                                final num = int.tryParse(
                                                  newValue.text,
                                                );
                                                if (num != null &&
                                                    num >= 0 &&
                                                    num <= 100) {
                                                  return newValue;
                                                }
                                                if (newValue.text.isEmpty) {
                                                  return newValue;
                                                }
                                                if (num == null) {
                                                  return oldValue;
                                                }
                                                if (num < 0) {
                                                  return TextEditingValue(
                                                    text: '0',
                                                    selection:
                                                        TextSelection.collapsed(
                                                          offset: 1,
                                                        ),
                                                  );
                                                }
                                                if (num > 100) {
                                                  return TextEditingValue(
                                                    text: '100',
                                                    selection:
                                                        TextSelection.collapsed(
                                                          offset: 3,
                                                        ),
                                                  );
                                                }
                                                return oldValue;
                                              }),
                                            ],
                                            decoration: InputDecoration(
                                              hintText: 'Vol',
                                              isDense: true,
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                            ),
                                            textAlign: TextAlign.center,
                                            onChanged: (text) {
                                              final value = int.tryParse(text);
                                              if (value != null &&
                                                  value >= 0 &&
                                                  value <= 100) {
                                                final doubleVolume =
                                                    value / 100.0;
                                                if (prefs.volume !=
                                                    doubleVolume) {
                                                  ref
                                                      .read(
                                                        preferencesProvider
                                                            .notifier,
                                                      )
                                                      .setVolume(doubleVolume);
                                                  if (!Platform.isAndroid) {
                                                    _audioPlayer.setVolume(
                                                      value.toDouble(),
                                                    );
                                                  }
                                                }
                                              }
                                            },
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
          if (_isBuffering) const Center(child: CircularProgressIndicator()),
          if (_playbackError != null && !_isBuffering)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _playbackError!,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
