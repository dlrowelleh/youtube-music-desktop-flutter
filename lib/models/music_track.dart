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
}
