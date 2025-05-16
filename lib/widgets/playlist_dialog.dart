import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../providers/playlist_provider.dart';
import '../models/playlist.dart';
import '../models/music_track.dart';

class PlaylistDialog extends ConsumerStatefulWidget {
  final Playlist? playlist;

  const PlaylistDialog({super.key, this.playlist});

  @override
  ConsumerState<PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends ConsumerState<PlaylistDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _urlController;
  bool _isImportMode = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.playlist?.description ?? '',
    );
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.playlist != null
            ? 'Edit Playlist'
            : _isImportMode
            ? 'Import from YouTube'
            : 'Create Playlist',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.playlist == null) ...[
              // Only show radio buttons for new playlist
              ListTile(
                title: const Text('Create new playlist'),
                leading: Radio<bool>(
                  value: false,
                  groupValue: _isImportMode,
                  onChanged: (value) => setState(() => _isImportMode = value!),
                ),
              ),
              ListTile(
                title: const Text('Import from YouTube'),
                leading: Radio<bool>(
                  value: true,
                  groupValue: _isImportMode,
                  onChanged: (value) => setState(() => _isImportMode = value!),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!_isImportMode || widget.playlist != null) ...[
              // Show name/description for new or edit
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter playlist name',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter playlist description (optional)',
                ),
                maxLines: 2,
              ),
            ] else ...[
              // Show URL field for import mode
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'YouTube Playlist URL',
                  hintText: 'https://www.youtube.com/playlist?list=...',
                ),
                autofocus: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (widget.playlist != null) {
              // Edit mode
              final name = _nameController.text.trim();
              if (name.isEmpty) return;

              ref
                  .read(playlistsProvider.notifier)
                  .updatePlaylist(
                    widget.playlist!.id,
                    name: name,
                    description: _descriptionController.text.trim(),
                  );
              Navigator.of(context).pop();
            } else if (_isImportMode) {
              // Import mode
              final url = _urlController.text.trim();
              if (!url.contains('youtube.com/playlist?list=') &&
                  !url.contains('youtu.be/playlist?list=')) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid YouTube playlist URL'),
                  ),
                );
                return;
              }

              try {
                final youtube = yt.YoutubeExplode();
                final ytPlaylist = await youtube.playlists.get(url);
                final videos =
                    await youtube.playlists.getVideos(ytPlaylist.id).toList();

                if (!mounted) return;

                ref
                    .read(playlistsProvider.notifier)
                    .createPlaylist(
                      ytPlaylist.title,
                      description: ytPlaylist.description,
                      youtubePlaylistUrl: url,
                      youtubePlaylistId: ytPlaylist.id.value,
                    );

                final createdPlaylist = ref.read(playlistsProvider).last;
                for (final video in videos) {
                  ref
                      .read(playlistsProvider.notifier)
                      // Replace .addTrackToPlaylist(createdPlaylist.id, video.id.value);
                      // with .addTrackToPlaylist(createdPlaylist.id, MusicTrack.fromVideoInfo(video));
                      // Replace updatePlaylist's trackIds param with tracks param (List<MusicTrack>).
                      .addTrackToPlaylist(
                        createdPlaylist.id,
                        MusicTrack.fromVideoInfo(video),
                      );
                }

                youtube.close();
                if (!mounted) return;
                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Failed to import playlist. Please check the URL and try again.',
                    ),
                  ),
                );
              }
            } else {
              // Create mode
              final name = _nameController.text.trim();
              if (name.isEmpty) return;

              ref
                  .read(playlistsProvider.notifier)
                  .createPlaylist(
                    name,
                    description: _descriptionController.text.trim(),
                  );
              Navigator.of(context).pop();
            }
          },
          child: Text(widget.playlist == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
