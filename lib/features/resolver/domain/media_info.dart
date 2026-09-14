import 'media_format.dart';

class MediaInfo {
  final String platform; // 'youtube', 'tiktok', 'facebook', 'instagram', 'twitter', 'vimeo', 'direct'
  final String mediaId;
  final String title;
  final String author;
  final String? thumbnailUrl;
  final Duration duration;
  final String? description;
  final Uri sourceUrl;
  final List<MediaFormat> formats;

  const MediaInfo({
    required this.platform,
    required this.mediaId,
    required this.title,
    required this.author,
    this.thumbnailUrl,
    required this.duration,
    this.description,
    required this.sourceUrl,
    required this.formats,
  });

  List<MediaFormat> get videoFormats =>
      formats.where((f) => f.hasVideo).toList();

  List<MediaFormat> get audioFormats =>
      formats.where((f) => f.formatType == FormatType.audio).toList();

  MediaFormat? get bestAudio =>
      audioFormats.firstWhere((f) => f.isBestAudio, orElse: () => audioFormats.first);

  MediaFormat? get highestQualityVideo {
    final v = videoFormats;
    if (v.isEmpty) return null;
    v.sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    return v.first;
  }

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
