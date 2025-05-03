import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NavigationSection { home, search, playlists }

final currentSectionProvider = StateProvider<NavigationSection>(
  (ref) => NavigationSection.home,
);

class AppNavigationRail extends ConsumerWidget {
  const AppNavigationRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSection = ref.watch(currentSectionProvider);

    return NavigationRail(
      selectedIndex: currentSection.index,
      onDestinationSelected: (index) {
        ref.read(currentSectionProvider.notifier).state =
            NavigationSection.values[index];
      },
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.home), label: Text('Home')),
        NavigationRailDestination(
          icon: Icon(Icons.search),
          label: Text('Search'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.playlist_play),
          label: Text('Playlists'),
        ),
      ],
    );
  }
}
