import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playlist_provider.dart';
import '../providers/music_provider.dart';
import '../widgets/playlist_dialog.dart';
import 'playlist_details_screen.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final currentTrack = ref.watch(currentTrackProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const PlaylistDialog(),
              );
            },
          ),
        ],
      ),
      body:
          playlists.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.queue_music, size: 64, color: Colors.grey),
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
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(playlist.name),
                    subtitle: Text(
                      '${playlist.trackIds.length} tracks${playlist.description.isNotEmpty ? ' • ${playlist.description}' : ''}',
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder:
                          (context) => [
                            PopupMenuItem(
                              child: const Text('Edit'),
                              onTap: () {
                                Future.delayed(
                                  const Duration(seconds: 0),
                                  () => showDialog(
                                    context: context,
                                    builder:
                                        (context) =>
                                            PlaylistDialog(playlist: playlist),
                                  ),
                                );
                              },
                            ),
                            if (currentTrack != null)
                              PopupMenuItem(
                                child: const Text('Add current track'),
                                onTap: () {
                                  ref
                                      .read(playlistsProvider.notifier)
                                      .addTrackToPlaylist(
                                        playlist.id,
                                        currentTrack.id,
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Added "${currentTrack.title}" to "${playlist.name}"',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            PopupMenuItem(
                              child: const Text('Delete'),
                              onTap: () {
                                ref
                                    .read(playlistsProvider.notifier)
                                    .deletePlaylist(playlist.id);
                              },
                            ),
                          ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PlaylistDetailsScreen(
                            playlist: playlist,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
