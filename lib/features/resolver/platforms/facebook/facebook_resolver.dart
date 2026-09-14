import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/media_format.dart';
import '../../domain/media_info.dart';
import '../../domain/media_resolver.dart';

class FacebookResolver implements MediaResolver {
  final http.Client _client;

  FacebookResolver({http.Client? client}) : _client = client ?? http.Client();

  @override
  bool supports(Uri url) {
    final host = url.host.toLowerCase();
    return host.contains('facebook.com') || host.contains('fb.watch') || host.contains('fb.me');
  }

  @override
  Future<MediaInfo> analyze(Uri url) async {
    final response = await _client.get(
      url,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-Mode': 'navigate',
      },
    );

    final html = response.body;

    // HD URL pattern
    String? hdUrl = _extractUrl(html, r'"playable_url_quality_hd"\s*:\s*"([^"]+)"') ??
        _extractUrl(html, r'"browser_native_hd_url"\s*:\s*"([^"]+)"');

    // SD URL pattern
    String? sdUrl = _extractUrl(html, r'"playable_url"\s*:\s*"([^"]+)"') ??
        _extractUrl(html, r'"browser_native_sd_url"\s*:\s*"([^"]+)"');

    if (hdUrl == null && sdUrl == null) {
      throw FormatException('No downloadable stream found for Facebook video: $url');
    }

    // Title & thumbnail extraction
    final titleMatch = RegExp(r'<meta\s+property="og:title"\s+content="([^"]*)"').firstMatch(html);
    final title = titleMatch?.group(1)?.replaceAll('&amp;', '&') ?? 'Facebook Video';

    final thumbMatch = RegExp(r'<meta\s+property="og:image"\s+content="([^"]*)"').firstMatch(html);
    final thumbnail = thumbMatch?.group(1)?.replaceAll('&amp;', '&');

    final formats = <MediaFormat>[];

    if (hdUrl != null) {
      formats.add(MediaFormat(
        formatId: 'fb_hd',
        formatType: FormatType.video,
        container: 'mp4',
        resolution: '720p HD',
        height: 720,
        videoCodec: 'h264',
        audioCodec: 'aac',
        hasVideo: true,
        hasAudio: true,
        streamUrl: Uri.parse(hdUrl),
      ));
    }

    if (sdUrl != null) {
      formats.add(MediaFormat(
        formatId: 'fb_sd',
        formatType: FormatType.video,
        container: 'mp4',
        resolution: '360p SD',
        height: 360,
        videoCodec: 'h264',
        audioCodec: 'aac',
        hasVideo: true,
        hasAudio: true,
        streamUrl: Uri.parse(sdUrl),
      ));
    }

    // Best audio format
    final primaryAudioStream = hdUrl ?? sdUrl!;
    formats.add(MediaFormat(
      formatId: 'fb_audio',
      formatType: FormatType.audio,
      container: 'm4a',
      audioCodec: 'aac',
      bitrate: 128000,
      hasVideo: false,
      hasAudio: true,
      streamUrl: Uri.parse(primaryAudioStream),
      isBestAudio: true,
    ));

    return MediaInfo(
      platform: 'facebook',
      mediaId: url.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'fb_video'),
      title: title,
      author: 'Facebook Creator',
      thumbnailUrl: thumbnail,
      duration: const Duration(minutes: 1),
      sourceUrl: url,
      formats: formats,
    );
  }

  @override
  Future<List<MediaFormat>> getFormats(Uri url) async {
    final info = await analyze(url);
    return info.formats;
  }

  String? _extractUrl(String html, String regex) {
    final match = RegExp(regex).firstMatch(html);
    if (match == null) return null;
    final raw = match.group(1);
    if (raw == null) return null;
    return _cleanJsonUrl(raw);
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
