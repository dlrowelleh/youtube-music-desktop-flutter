import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'search_bar.dart';
import 'search_results.dart';
import '../providers/music_provider.dart';

class SearchSection extends ConsumerStatefulWidget {
  const SearchSection({super.key});

  @override
  ConsumerState<SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends ConsumerState<SearchSection> {
  bool _cleared = false;

  @override
  void initState() {
    super.initState();
    Future(() async {
      if (mounted) {
        await ref.read(searchResultsProvider.notifier).loadVideo('');
        if (mounted) {
          setState(() {
            _cleared = true;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cleared) {
      return const SizedBox.shrink();
    }
    return const Column(
      children: [
        Padding(padding: EdgeInsets.all(16.0), child: MusicSearchBar()),
        Expanded(child: SearchResults()),
      ],
    );
  }
}
