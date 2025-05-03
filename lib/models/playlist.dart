class Playlist {
  final String id;
  final String name;
  final String description;
  final List<String> trackIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Playlist({
    required this.id,
    required this.name,
    this.description = '',
    List<String>? trackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : trackIds = trackIds ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Playlist copyWith({
    String? name,
    String? description,
    List<String>? trackIds,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'trackIds': trackIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      trackIds: (json['trackIds'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
