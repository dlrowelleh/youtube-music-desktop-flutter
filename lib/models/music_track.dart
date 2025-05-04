class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final Duration duration;
  final String url;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.duration,
    required this.url,
  });

  factory MusicTrack.fromVideoInfo(dynamic videoInfo) {
    return MusicTrack(
      id: videoInfo.id.value,
      title: videoInfo.title,
      artist: videoInfo.author,
      thumbnailUrl: videoInfo.thumbnails.highResUrl,
      duration: videoInfo.duration ?? Duration.zero,
      url: '', // Will be set when streaming
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration.inMilliseconds,
      'url': url,
    };
  }

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      url: json['url'] as String,
    );
  }
}
