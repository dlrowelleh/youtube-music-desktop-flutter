import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  final double volume;
  final String? lastPlayedTrackId;
  final List<String> recentPlaylistIds;
  final bool shuffleEnabled;
  final bool repeatEnabled;

  const Preferences({
    this.volume = 1.0,
    this.lastPlayedTrackId,
    this.recentPlaylistIds = const [],
    this.shuffleEnabled = false,
    this.repeatEnabled = false,
  });

  Map<String, dynamic> toJson() => {
    'volume': volume,
    'lastPlayedTrackId': lastPlayedTrackId,
    'recentPlaylistIds': recentPlaylistIds,
    'shuffleEnabled': shuffleEnabled,
    'repeatEnabled': repeatEnabled,
  };

  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
    volume: json['volume'] as double? ?? 1.0,
    lastPlayedTrackId: json['lastPlayedTrackId'] as String?,
    recentPlaylistIds: List<String>.from(
      json['recentPlaylistIds'] as List? ?? [],
    ),
    shuffleEnabled: json['shuffleEnabled'] as bool? ?? false,
    repeatEnabled: json['repeatEnabled'] as bool? ?? false,
  );

  Preferences copyWith({
    double? volume,
    String? lastPlayedTrackId,
    List<String>? recentPlaylistIds,
    bool? shuffleEnabled,
    bool? repeatEnabled,
  }) => Preferences(
    volume: volume ?? this.volume,
    lastPlayedTrackId: lastPlayedTrackId ?? this.lastPlayedTrackId,
    recentPlaylistIds: recentPlaylistIds ?? this.recentPlaylistIds,
    shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
    repeatEnabled: repeatEnabled ?? this.repeatEnabled,
  );
}

class PreferencesService {
  static const _key = 'app_preferences';
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  Future<void> savePreferences(Preferences preferences) async {
    final json = jsonEncode(preferences.toJson());
    await _prefs.setString(_key, json);
  }

  Preferences loadPreferences() {
    final json = _prefs.getString(_key);
    if (json == null) return const Preferences();

    try {
      return Preferences.fromJson(jsonDecode(json));
    } catch (e) {
      return const Preferences();
    }
  }

  Future<void> setLastPlayedTrack(String trackId) async {
    final preferences = loadPreferences();
    final updatedPreferences = preferences.copyWith(lastPlayedTrackId: trackId);
    await savePreferences(updatedPreferences);
  }
}
