import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../providers/playlist_provider.dart';

class YoutubePlaylistDialog extends ConsumerStatefulWidget {
  const YoutubePlaylistDialog({super.key});

  @override
  ConsumerState<YoutubePlaylistDialog> createState() =>
      _YoutubePlaylistDialogState();
}

class _YoutubePlaylistDialogState extends ConsumerState<YoutubePlaylistDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _importPlaylist() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final yt = YoutubeExplode();
      final url = _urlController.text.trim();
      final playlist = await yt.playlists.get(url);
      final videos = await yt.playlists.getVideos(playlist.id).toList();

      if (!mounted) return;

      ref
          .read(playlistsProvider.notifier)
          .createPlaylist(
            playlist.title,
            description: playlist.description,
            youtubePlaylistUrl: url,
            youtubePlaylistId: playlist.id.value,
          );

      final createdPlaylist = ref.read(playlistsProvider).last;
      for (final video in videos) {
        ref.read(playlistsProvider.notifier);
        // Replace .addTrackToPlaylist(createdPlaylist.id, video.id.value);
        // with .addTrackToPlaylist(createdPlaylist.id, MusicTrack.fromVideoInfo(video));
      }

      yt.close();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error =
            'Failed to import playlist. Please check the URL and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import YouTube Playlist'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'YouTube Playlist URL',
                hintText: 'https://www.youtube.com/playlist?list=...',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a playlist URL';
                }
                if (!value.contains('youtube.com/playlist?list=') &&
                    !value.contains('youtu.be/playlist?list=')) {
                  return 'Please enter a valid YouTube playlist URL';
                }
                return null;
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _importPlaylist,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Import'),
        ),
      ],
    );
  }
}
