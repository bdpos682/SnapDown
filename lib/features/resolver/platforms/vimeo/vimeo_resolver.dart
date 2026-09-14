import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/media_format.dart';
import '../../domain/media_info.dart';
import '../../domain/media_resolver.dart';

class VimeoResolver implements MediaResolver {
  final http.Client _client;

  VimeoResolver({http.Client? client}) : _client = client ?? http.Client();

  @override
  bool supports(Uri url) {
    final host = url.host.toLowerCase();
    return host.contains('vimeo.com');
  }

  @override
  Future<MediaInfo> analyze(Uri url) async {
    final videoId = _extractVideoId(url);
    if (videoId == null) {
      throw FormatException('Invalid Vimeo video URL: $url');
    }

    final configUrl = Uri.parse('https://player.vimeo.com/video/$videoId/config');
    final response = await _client.get(
      configUrl,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
    );

    if (response.statusCode != 200) {
      throw FormatException('Failed to fetch Vimeo video config: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final video = data['video'] as Map<String, dynamic>? ?? {};
    final title = video['title'] as String? ?? 'Vimeo Video';
    final durationSec = video['duration'] as int? ?? 0;
    final thumbs = video['thumbs'] as Map<String, dynamic>? ?? {};
    final thumbnail = thumbs['base'] as String? ?? (thumbs.values.isNotEmpty ? thumbs.values.first as String : null);
    final user = video['owner'] as Map<String, dynamic>? ?? {};
    final author = user['name'] as String? ?? 'Vimeo Creator';

    final request = data['request'] as Map<String, dynamic>? ?? {};
    final files = request['files'] as Map<String, dynamic>? ?? {};
    final progressive = files['progressive'] as List<dynamic>? ?? [];

    if (progressive.isEmpty) {
      throw FormatException('No progressive MP4 files found for Vimeo video: $url');
    }

    // Sort progressive streams by quality descending
    progressive.sort((a, b) {
      final hA = a['height'] as int? ?? 0;
      final hB = b['height'] as int? ?? 0;
      return hB.compareTo(hA);
    });

    final formats = <MediaFormat>[];
    for (int i = 0; i < progressive.length; i++) {
      final item = progressive[i] as Map<String, dynamic>;
      final streamUrl = item['url'] as String?;
      if (streamUrl == null) continue;

      final height = item['height'] as int?;
      final width = item['width'] as int?;
      final fps = item['fps'] as int?;
      final quality = item['quality'] as String? ?? '${height}p';

      formats.add(MediaFormat(
        formatId: 'vimeo_$quality',
        formatType: FormatType.video,
        container: 'mp4',
        resolution: '${quality}p',
        width: width,
        height: height,
        fps: fps,
        videoCodec: 'h264',
        audioCodec: 'aac',
        hasVideo: true,
        hasAudio: true,
        streamUrl: Uri.parse(streamUrl),
      ));
    }

    // Audio format
    final bestUrl = progressive.first['url'] as String;
    formats.add(MediaFormat(
      formatId: 'vimeo_audio',
      formatType: FormatType.audio,
      container: 'm4a',
      audioCodec: 'aac',
      bitrate: 128000,
      hasVideo: false,
      hasAudio: true,
      streamUrl: Uri.parse(bestUrl),
      isBestAudio: true,
    ));

    return MediaInfo(
      platform: 'vimeo',
      mediaId: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnail,
      duration: Duration(seconds: durationSec),
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
    for (final seg in url.pathSegments.reversed) {
      if (RegExp(r'^\d+$').hasMatch(seg)) {
        return seg;
      }
    }
    return null;
  }
}
