import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/enhanced_music_player.dart';
import '../widgets/app_navigation_rail.dart';
import '../widgets/home_section.dart';
import '../widgets/search_section.dart';
import '../widgets/playlist_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          const AppNavigationRail(),
          Expanded(
            child: Stack(
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final currentSection = ref.watch(currentSectionProvider);
                    return switch (currentSection) {
                      NavigationSection.home => const HomeSection(),
                      NavigationSection.search => const SearchSection(),
                      NavigationSection.playlists => const PlaylistSection(),
                      _ => const HomeSection(),
                    };
                  },
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: EnhancedMusicPlayer(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
