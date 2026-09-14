import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../../../core/utils/html_utils.dart';
import '../../domain/media_format.dart';
import '../../domain/media_info.dart';
import '../../domain/media_resolver.dart';

class YoutubeResolver implements MediaResolver {
  final yt.YoutubeExplode _yt;
  static final Map<String, yt.StreamManifest> _manifestCache = {};

  static yt.StreamManifest? getCachedManifest(String videoId) => _manifestCache[videoId];
  static void cacheManifest(String videoId, yt.StreamManifest manifest) {
    _manifestCache[videoId] = manifest;
  }

  YoutubeResolver({yt.YoutubeExplode? client}) : _yt = client ?? yt.YoutubeExplode();

  @override
  bool supports(Uri url) {
    final host = url.host.toLowerCase();
    return host.contains('youtube.com') || host.contains('youtu.be');
  }

  @override
  Future<MediaInfo> analyze(Uri url) async {
    final videoId = _extractVideoId(url);
    if (videoId == null) {
      throw FormatException('Invalid YouTube URL: $url');
    }

    String title = 'YouTube Video';
    String author = 'YouTube Creator';
    String? thumbnailUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    Duration duration = Duration.zero;
    String description = '';

    // 1. Lấy thông tin metadata với phương án dự phòng oEmbed nếu bị YouTube rate-limit trang watch
    try {
      final video = await _yt.videos.get(videoId);
      title = video.title;
      author = video.author;
      thumbnailUrl = video.thumbnails.highResUrl;
      duration = video.duration ?? Duration.zero;
      description = video.description;
    } catch (e) {
      try {
        final oembedUri = Uri.parse(
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json',
        );
        final oembedRes = await http.get(oembedUri).timeout(const Duration(seconds: 6));
        if (oembedRes.statusCode == 200) {
          final data = jsonDecode(oembedRes.body) as Map<String, dynamic>;
          title = data['title'] as String? ?? title;
          author = data['author_name'] as String? ?? author;
          thumbnailUrl = data['thumbnail_url'] as String? ?? thumbnailUrl;
        }
      } catch (_) {}
    }

    title = HtmlUtils.unescape(title);
    author = HtmlUtils.unescape(author);

    // 2. Lấy manifest luồng dữ liệu (với fallback requireWatchPage: false nếu bị chặn)
    yt.StreamManifest? manifest;
    try {
      manifest = await _yt.videos.streamsClient.getManifest(videoId);
    } catch (e) {
      try {
        manifest = await _yt.videos.streamsClient.getManifest(videoId, requireWatchPage: false);
      } catch (e2) {
        rethrow;
      }
    }

    _manifestCache[videoId] = manifest;

    final formats = <MediaFormat>[];

    // Find the best audio stream to pair with video-only streams
    final audioOnlyStreams = manifest.audioOnly.toList();
    audioOnlyStreams.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
    final bestAudioStream = audioOnlyStreams.isNotEmpty ? audioOnlyStreams.first : null;

    // 1. Process Video-Only & Muxed streams
    // Group by resolution to keep only the highest bitrate per resolution
    final videoStreams = <String, yt.VideoStreamInfo>{};
    for (final stream in manifest.video) {
      final resKey = '${stream.videoResolution.height}p';
      final existing = videoStreams[resKey];
      if (existing == null || stream.bitrate.bitsPerSecond > existing.bitrate.bitsPerSecond) {
        videoStreams[resKey] = stream;
      }
    }

    final sortedHeights = videoStreams.keys.toList()
      ..sort((a, b) {
        final ha = int.tryParse(a.replaceAll('p', '')) ?? 0;
        final hb = int.tryParse(b.replaceAll('p', '')) ?? 0;
        return hb.compareTo(ha);
      });

    for (final key in sortedHeights) {
      final stream = videoStreams[key]!;
      final isVideoOnly = stream is yt.VideoOnlyStreamInfo;
      final pairedAudioUrl = isVideoOnly ? bestAudioStream?.url : null;

      final estSize = stream.size.totalBytes +
          (isVideoOnly && bestAudioStream != null ? bestAudioStream.size.totalBytes : 0);

      formats.add(MediaFormat(
        formatId: 'yt_${stream.tag}',
        formatType: FormatType.video,
        container: stream.container.name,
        resolution: key,
        width: stream.videoResolution.width,
        height: stream.videoResolution.height,
        fps: stream.framerate.framesPerSecond.round(),
        videoCodec: stream.videoCodec,
        audioCodec: isVideoOnly ? bestAudioStream?.audioCodec : 'aac',
        bitrate: stream.bitrate.bitsPerSecond,
        estimatedSizeBytes: estSize,
        hasVideo: true,
        hasAudio: !isVideoOnly || pairedAudioUrl != null,
        streamUrl: stream.url,
        audioStreamUrl: pairedAudioUrl,
      ));
    }

    // 2. Process Audio-Only streams
    bool isFirstAudio = true;
    for (final audio in audioOnlyStreams) {
      formats.add(MediaFormat(
        formatId: 'yt_audio_${audio.tag}',
        formatType: FormatType.audio,
        container: audio.container.name,
        audioCodec: audio.audioCodec,
        bitrate: audio.bitrate.bitsPerSecond,
        estimatedSizeBytes: audio.size.totalBytes,
        hasVideo: false,
        hasAudio: true,
        streamUrl: audio.url,
        isBestAudio: isFirstAudio,
      ));
      isFirstAudio = false;
    }

    return MediaInfo(
      platform: 'youtube',
      mediaId: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      description: description,
      sourceUrl: url,
      formats: formats,
    );
  }

  @override
  Future<List<MediaFormat>> getFormats(Uri url) async {
    final info = await analyze(url);
    return info.formats;
  }

  String? _extractVideoId(Uri url) {
    if (url.host.contains('youtu.be')) {
      return url.pathSegments.isNotEmpty ? url.pathSegments.first : null;
    }
    if (url.pathSegments.contains('watch')) {
      return url.queryParameters['v'];
    }
    if (url.pathSegments.contains('shorts')) {
      final index = url.pathSegments.indexOf('shorts');
      if (index + 1 < url.pathSegments.length) {
        return url.pathSegments[index + 1];
      }
    }
    return null;
  }
}
