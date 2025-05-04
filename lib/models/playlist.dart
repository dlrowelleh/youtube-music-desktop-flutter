import 'music_track.dart';

class Playlist {
  final String id;
  final String name;
  final String description;
  final List<MusicTrack> tracks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? youtubePlaylistUrl;
  final String? youtubePlaylistId;

  Playlist({
    required this.id,
    required this.name,
    this.description = '',
    List<MusicTrack>? tracks,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.youtubePlaylistUrl,
    this.youtubePlaylistId,
  }) : tracks = tracks ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Playlist copyWith({
    String? name,
    String? description,
    List<MusicTrack>? tracks,
    DateTime? updatedAt,
    String? youtubePlaylistUrl,
    String? youtubePlaylistId,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      youtubePlaylistUrl: youtubePlaylistUrl ?? this.youtubePlaylistUrl,
      youtubePlaylistId: youtubePlaylistId ?? this.youtubePlaylistId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'tracks': tracks.map((track) => track.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'youtubePlaylistUrl': youtubePlaylistUrl,
      'youtubePlaylistId': youtubePlaylistId,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      tracks:
          (json['tracks'] as List<dynamic>?)
              ?.map(
                (trackJson) =>
                    MusicTrack.fromJson(trackJson as Map<String, dynamic>),
              )
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      youtubePlaylistUrl: json['youtubePlaylistUrl'] as String?,
      youtubePlaylistId: json['youtubePlaylistId'] as String?,
    );
  }
}
