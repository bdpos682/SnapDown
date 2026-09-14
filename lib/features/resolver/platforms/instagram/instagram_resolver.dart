import 'package:http/http.dart' as http;
import '../../domain/media_format.dart';
import '../../domain/media_info.dart';
import '../../domain/media_resolver.dart';

class InstagramResolver implements MediaResolver {
  final http.Client _client;

  InstagramResolver({http.Client? client}) : _client = client ?? http.Client();

  @override
  bool supports(Uri url) {
    final host = url.host.toLowerCase();
    return host.contains('instagram.com');
  }

  @override
  Future<MediaInfo> analyze(Uri url) async {
    final shortcode = _extractShortcode(url);
    if (shortcode == null) {
      throw FormatException('Invalid Instagram post/reel URL: $url');
    }

    final embedUrl = Uri.parse('https://www.instagram.com/p/$shortcode/embed/captioned/');
    final response = await _client.get(
      embedUrl,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
      },
    );

    final html = response.body;

    // Search for video URL in script tags or video element
    String? videoUrl;
    final videoMatch = RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(html) ??
        RegExp(r'<video[^>]+src="([^">]+)"').firstMatch(html);

    if (videoMatch != null) {
      videoUrl = videoMatch.group(1)?.replaceAll(r'\u0026', '&').replaceAll(r'\/', '/');
    }

    if (videoUrl == null) {
      throw FormatException('Could not extract video stream from Instagram URL: $url');
    }

    // Thumbnail extraction
    final thumbMatch = RegExp(r'"display_url"\s*:\s*"([^"]+)"').firstMatch(html) ??
        RegExp(r'<img[^>]+class="EmbeddedMediaImage"[^>]+src="([^">]+)"').firstMatch(html);
    final thumbnail = thumbMatch?.group(1)?.replaceAll(r'\u0026', '&').replaceAll(r'\/', '/');

    // Title / Caption
    final captionMatch = RegExp(r'<div class="Caption"[^>]*>(.*?)<\/div>', dotAll: true).firstMatch(html);
    final title = captionMatch?.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    final formats = <MediaFormat>[
      MediaFormat(
        formatId: 'ig_video_hd',
        formatType: FormatType.video,
        container: 'mp4',
        resolution: '1080p',
        width: 1080,
        height: 1920,
        videoCodec: 'h264',
        audioCodec: 'aac',
        hasVideo: true,
        hasAudio: true,
        streamUrl: Uri.parse(videoUrl),
      ),
      MediaFormat(
        formatId: 'ig_audio',
        formatType: FormatType.audio,
        container: 'm4a',
        audioCodec: 'aac',
        bitrate: 128000,
        hasVideo: false,
        hasAudio: true,
        streamUrl: Uri.parse(videoUrl),
        isBestAudio: true,
      ),
    ];

    return MediaInfo(
      platform: 'instagram',
      mediaId: shortcode,
      title: title != null && title.isNotEmpty ? (title.length > 50 ? '${title.substring(0, 50)}...' : title) : 'Instagram Video',
      author: 'Instagram Creator',
      thumbnailUrl: thumbnail,
      duration: const Duration(seconds: 30),
      sourceUrl: url,
      formats: formats,
    );
  }

  @override
  Future<List<MediaFormat>> getFormats(Uri url) async {
    final info = await analyze(url);
    return info.formats;
  }

  String? _extractShortcode(Uri url) {
    final segments = url.pathSegments;
    for (int i = 0; i < segments.length; i++) {
      if (segments[i] == 'p' || segments[i] == 'reel' || segments[i] == 'tv') {
        if (i + 1 < segments.length) return segments[i + 1];
      }
    }
    return segments.isNotEmpty ? segments.first : null;
  }
}
