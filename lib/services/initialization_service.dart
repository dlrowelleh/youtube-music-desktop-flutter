import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/preferences_provider.dart';
import '../providers/music_provider.dart';

class InitializationService {
  static Future<ProviderContainer> initializeApp() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
    );

    // Initialize empty search results
    container.read(searchResultsProvider.notifier).state = [];

    return container;
  }
}
