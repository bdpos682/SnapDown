import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/media_format.dart';
import '../../domain/media_info.dart';
import '../../domain/media_resolver.dart';

class TwitterResolver implements MediaResolver {
  final http.Client _client;

  TwitterResolver({http.Client? client}) : _client = client ?? http.Client();

  @override
  bool supports(Uri url) {
    final host = url.host.toLowerCase();
    return host.contains('twitter.com') || host.contains('x.com');
  }

  @override
  Future<MediaInfo> analyze(Uri url) async {
    final tweetId = _extractTweetId(url);
    if (tweetId == null) {
      throw FormatException('Invalid Twitter/X URL: $url');
    }

    final syndicationUrl = Uri.parse(
        'https://cdn.syndication.twimg.com/tweet-result?id=$tweetId&lang=en&token=404');
    final response = await _client.get(
      syndicationUrl,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
    );

    if (response.statusCode != 200) {
      throw FormatException('Failed to fetch Twitter/X post data: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['text'] as String? ?? 'X Post';
    final user = data['user'] as Map<String, dynamic>?;
    final authorName = user?['name'] as String? ?? 'Twitter User';

    // Locate video media
    List<dynamic>? variants;
    String? thumbnail;
    final mediaDetails = data['mediaDetails'] as List<dynamic>?;
    if (mediaDetails != null && mediaDetails.isNotEmpty) {
      for (final media in mediaDetails) {
        final type = media['type'] as String?;
        if (type == 'video' || type == 'animated_gif') {
          thumbnail = media['media_url_https'] as String?;
          final videoInfo = media['video_info'] as Map<String, dynamic>?;
          variants = videoInfo?['variants'] as List<dynamic>?;
          break;
        }
      }
    }

    if (variants == null || variants.isEmpty) {
      final video = data['video'] as Map<String, dynamic>?;
      variants = video?['variants'] as List<dynamic>?;
      thumbnail ??= video?['poster'] as String?;
    }

    if (variants == null || variants.isEmpty) {
      throw FormatException('No video stream found in Twitter/X post: $url');
    }

    // Filter MP4 formats and sort by bitrate descending
    final mp4Variants = variants
        .where((v) => (v['content_type'] as String? ?? '').contains('mp4'))
        .toList();

    mp4Variants.sort((a, b) {
      final brA = a['bitrate'] as int? ?? 0;
      final brB = b['bitrate'] as int? ?? 0;
      return brB.compareTo(brA);
    });

    if (mp4Variants.isEmpty) {
      throw FormatException('No playable MP4 variants found for Twitter/X post: $url');
    }

    final formats = <MediaFormat>[];
    for (int i = 0; i < mp4Variants.length; i++) {
      final v = mp4Variants[i];
      final src = v['src'] as String? ?? v['url'] as String?;
      if (src == null) continue;

      final bitrate = v['bitrate'] as int?;
      final res = _inferResolutionFromUrl(src) ?? (bitrate != null ? '${(bitrate / 1000).round()}k' : 'Default');

      formats.add(MediaFormat(
        formatId: 'tw_video_$i',
        formatType: FormatType.video,
        container: 'mp4',
        resolution: res,
        bitrate: bitrate,
        videoCodec: 'h264',
        audioCodec: 'aac',
        hasVideo: true,
        hasAudio: true,
        streamUrl: Uri.parse(src),
      ));
    }

    // Audio extraction format
    final bestVariantSrc = mp4Variants.first['src'] as String? ?? mp4Variants.first['url'] as String;
    formats.add(MediaFormat(
      formatId: 'tw_audio',
      formatType: FormatType.audio,
      container: 'm4a',
      audioCodec: 'aac',
      bitrate: 128000,
      hasVideo: false,
      hasAudio: true,
      streamUrl: Uri.parse(bestVariantSrc),
      isBestAudio: true,
    ));

    return MediaInfo(
      platform: 'twitter',
      mediaId: tweetId,
      title: text.length > 60 ? '${text.substring(0, 60)}...' : text,
      author: authorName,
      thumbnailUrl: thumbnail,
      duration: const Duration(seconds: 45),
      sourceUrl: url,
      formats: formats,
    );
  }

  @override
  Future<List<MediaFormat>> getFormats(Uri url) async {
    final info = await analyze(url);
    return info.formats;
  }

  String? _extractTweetId(Uri url) {
    final segments = url.pathSegments;
    final statusIndex = segments.indexOf('status');
    if (statusIndex != -1 && statusIndex + 1 < segments.length) {
      return segments[statusIndex + 1];
    }
    return null;
  }

  String? _inferResolutionFromUrl(String url) {
    final match = RegExp(r'/(\d+x\d+)/').firstMatch(url);
    if (match != null) {
      final parts = match.group(1)!.split('x');
      if (parts.length == 2) {
        return '${parts[1]}p';
      }
    }
    return null;
  }
}
