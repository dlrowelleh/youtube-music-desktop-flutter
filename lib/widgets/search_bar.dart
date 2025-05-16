import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';

class MusicSearchBar extends ConsumerStatefulWidget {
  const MusicSearchBar({super.key});

  @override
  ConsumerState<MusicSearchBar> createState() => _MusicSearchBarState();
}

class _MusicSearchBarState extends ConsumerState<MusicSearchBar> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _onSearchSubmitted(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;

    if (!_isSearching) {
      setState(() => _isSearching = true);
    }
    ref.read(searchResultsProvider.notifier).loadVideo(query.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: _onSearchSubmitted,
        enableInteractiveSelection: true,
        decoration: InputDecoration(
          hintText: 'Search YouTube music...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _isSearching
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchResultsProvider.notifier).loadVideo('');
                      setState(() => _isSearching = false);
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }
}
