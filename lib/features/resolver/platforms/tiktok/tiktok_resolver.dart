import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/media_format.dart';
import '../../domain/media_info.dart';
import '../../domain/media_resolver.dart';

class TiktokResolver implements MediaResolver {
  final http.Client _client;

  TiktokResolver({http.Client? client}) : _client = client ?? http.Client();

  @override
  bool supports(Uri url) {
    final host = url.host.toLowerCase();
    return host.contains('tiktok.com');
  }

  @override
  Future<MediaInfo> analyze(Uri url) async {
    // 1. Phân giải Shortlink (vt.tiktok.com, vm.tiktok.com) nếu cần
    Uri resolvedUrl = url;
    if (url.host.contains('vt.tiktok.com') || url.host.contains('vm.tiktok.com')) {
      try {
        final req = http.Request('GET', url)..followRedirects = true;
        final streamed = await _client.send(req);
        resolvedUrl = streamed.request?.url ?? url;
      } catch (_) {}
    }

    // 2. CHIẾN LƯỢC 1: TikWM API - Trả về luồng CDN chuẩn không dính 403, không watermark, kèm Audio MP3 gốc
    try {
      final tikwmUri = Uri.parse('https://www.tikwm.com/api/?url=${Uri.encodeComponent(resolvedUrl.toString())}');
      final response = await _client.get(
        tikwmUri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] == 0 && data['data'] != null) {
          final item = data['data'] as Map<String, dynamic>;
          final play = item['play'] as String?;
          final wmplay = item['wmplay'] as String?;
          final music = item['music'] as String?;
          final videoUrl = play ?? wmplay;

          if (videoUrl != null && videoUrl.isNotEmpty) {
            final formats = <MediaFormat>[
              MediaFormat(
                formatId: 'tiktok_hd_video',
                formatType: FormatType.video,
                container: 'mp4',
                resolution: '1080p',
                width: 1080,
                height: 1920,
                fps: 30,
                videoCodec: 'h264',
                audioCodec: 'aac',
                hasVideo: true,
                hasAudio: true,
                streamUrl: Uri.parse(videoUrl),
              ),
              if (wmplay != null && wmplay != play)
                MediaFormat(
                  formatId: 'tiktok_sd_video',
                  formatType: FormatType.video,
                  container: 'mp4',
                  resolution: '720p',
                  width: 720,
                  height: 1280,
                  fps: 30,
                  videoCodec: 'h264',
                  audioCodec: 'aac',
                  hasVideo: true,
                  hasAudio: true,
                  streamUrl: Uri.parse(wmplay),
                ),
              MediaFormat(
                formatId: 'tiktok_audio',
                formatType: FormatType.audio,
                container: 'mp3',
                audioCodec: 'mp3',
                bitrate: 192000,
                hasVideo: false,
                hasAudio: true,
                streamUrl: Uri.parse(music ?? videoUrl),
                isBestAudio: true,
              ),
            ];

            return MediaInfo(
              platform: 'tiktok',
              mediaId: item['id']?.toString() ??
                  resolvedUrl.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'tiktok'),
              title: (item['title'] as String?)?.trim().isNotEmpty == true
                  ? (item['title'] as String).trim()
                  : 'TikTok Video',
              author: item['author']?['nickname'] as String? ?? 'TikTok Creator',
              thumbnailUrl: item['cover'] as String?,
              duration: Duration(seconds: item['duration'] as int? ?? 30),
              sourceUrl: url,
              formats: formats,
            );
          }
        }
      }
    } catch (_) {}

    // 3. CHIẾN LƯỢC 2: Fallback Web Scraping (oEmbed + HTML Regex)
    final request = http.Request('GET', resolvedUrl)..followRedirects = true;
    request.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    final streamedResponse = await _client.send(request);
    final finalResponse = await http.Response.fromStream(streamedResponse);

    // Fetch oEmbed for metadata (title, author, thumbnail)
    final oembedUri = Uri.parse('https://www.tiktok.com/oembed?url=${Uri.encodeComponent(resolvedUrl.toString())}');
    final oembedRes = await _client.get(oembedUri);
    String title = 'TikTok Video';
    String author = 'TikTok Creator';
    String? thumbnail;

    if (oembedRes.statusCode == 200) {
      try {
        final data = jsonDecode(oembedRes.body);
        title = data['title'] as String? ?? title;
        author = data['author_name'] as String? ?? author;
        thumbnail = data['thumbnail_url'] as String?;
      } catch (_) {}
    }

    // Extract playAddr or video source from HTML
    final html = finalResponse.body;
    String? rawVideoUrl;

    final playAddrMatch = RegExp(r'"playAddr"\s*:\s*"([^"]+)"').firstMatch(html);
    if (playAddrMatch != null) {
      rawVideoUrl = playAddrMatch.group(1);
    }

    if (rawVideoUrl == null) {
      final downloadAddrMatch = RegExp(r'"downloadAddr"\s*:\s*"([^"]+)"').firstMatch(html);
      if (downloadAddrMatch != null) {
        rawVideoUrl = downloadAddrMatch.group(1);
      }
    }

    if (rawVideoUrl == null) {
      final videoTagMatch = RegExp(r'<video[^>]+src="([^">]+)"').firstMatch(html);
      if (videoTagMatch != null) {
        rawVideoUrl = videoTagMatch.group(1);
      }
    }

    if (rawVideoUrl == null) {
      throw FormatException('Could not resolve video stream from TikTok URL: $url');
    }

    final videoUrl = _cleanJsonUrl(rawVideoUrl);

    final formats = <MediaFormat>[
      MediaFormat(
        formatId: 'tiktok_hd_video',
        formatType: FormatType.video,
        container: 'mp4',
        resolution: '1080p',
        width: 1080,
        height: 1920,
        fps: 30,
        videoCodec: 'h264',
        audioCodec: 'aac',
        hasVideo: true,
        hasAudio: true,
        streamUrl: Uri.parse(videoUrl),
      ),
      MediaFormat(
        formatId: 'tiktok_audio',
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
      platform: 'tiktok',
      mediaId: resolvedUrl.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'tiktok'),
      title: title,
      author: author,
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

  String _cleanJsonUrl(String raw) {
    String s = raw;
    try {
      s = jsonDecode('"$s"') as String;
    } catch (_) {}
    s = s
        .replaceAll(RegExp(r'\\?u002[fF]', caseSensitive: false), '/')
        .replaceAll(r'\/', '/')
        .replaceAll(RegExp(r'\\?u0026', caseSensitive: false), '&')
        .replaceAll(r'\\', '');

    final isHttp = s.startsWith('http:');
    s = s.replaceFirst(RegExp(r'^https?:/+', caseSensitive: false), '');
    s = isHttp ? 'http://$s' : 'https://$s';

    final uri = Uri.tryParse(s);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      final cleanPath = uri.path.replaceAll(RegExp(r'/+'), '/');
      return uri.replace(path: cleanPath).toString();
    }
    return s;
  }
}
