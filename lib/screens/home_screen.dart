import 'dart:io' show Platform;
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
    final currentSection = ref.watch(currentSectionProvider);
    final isAndroid = Platform.isAndroid;

    Widget buildBody() {
      return Stack(
        children: [
          Consumer(
            builder: (context, ref, child) {
              return switch (currentSection) {
                NavigationSection.home => const HomeSection(),
                NavigationSection.search => const SearchSection(),
                NavigationSection.playlists => const PlaylistSection(),
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
      );
    }

    if (isAndroid) {
      return Scaffold(
        body: buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentSection.index,
          onTap: (index) {
            ref.read(currentSectionProvider.notifier).state =
                NavigationSection.values[index];
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(
              icon: Icon(Icons.playlist_play),
              label: 'Playlists',
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        body: Row(
          children: [const AppNavigationRail(), Expanded(child: buildBody())],
        ),
      );
    }
  }
}
