import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playlist_provider.dart';
import '../widgets/playlist_dialog.dart';
import '../screens/playlist_details_screen.dart';

class PlaylistSection extends ConsumerWidget {
  const PlaylistSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Your Playlists',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const PlaylistDialog(),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Playlist'),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              playlists.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.queue_music,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text('No playlists yet'),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const PlaylistDialog(),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Playlist'),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.queue_music),
                          title: Text(playlist.name),
                          subtitle: Text(
                            '${playlist.tracks.length} tracks${playlist.description.isNotEmpty ? ' • ${playlist.description}' : ''}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder:
                                    (context) =>
                                        PlaylistDialog(playlist: playlist),
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (context) => PlaylistDetailsScreen(
                                      playlist: playlist,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
