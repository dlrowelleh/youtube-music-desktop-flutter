import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../widgets/app_navigation_rail.dart';

class HomeSection extends ConsumerWidget {
  const HomeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to YouTube Music',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Search for your favorite music',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state =
                  NavigationSection.search;
            },
            icon: const Icon(Icons.search),
            label: const Text('Start Searching'),
          ),
        ],
      ),
    );
  }
}
