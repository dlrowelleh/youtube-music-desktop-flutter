import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playlist_provider.dart';
import '../models/playlist.dart';

class PlaylistDialog extends ConsumerStatefulWidget {
  final Playlist? playlist;

  const PlaylistDialog({super.key, this.playlist});

  @override
  ConsumerState<PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends ConsumerState<PlaylistDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.playlist?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.playlist == null ? 'Create Playlist' : 'Edit Playlist',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            if (widget.playlist == null) {
              ref
                  .read(playlistsProvider.notifier)
                  .createPlaylist(
                    name,
                    description: _descriptionController.text.trim(),
                  );
            } else {
              ref
                  .read(playlistsProvider.notifier)
                  .updatePlaylist(
                    widget.playlist!.id,
                    name: name,
                    description: _descriptionController.text.trim(),
                  );
            }

            Navigator.of(context).pop();
          },
          child: Text(widget.playlist == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
