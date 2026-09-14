import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../domain/media_format.dart';
import '../../domain/media_info.dart';
import '../../domain/media_resolver.dart';

class DirectResolver implements MediaResolver {
  final http.Client _client;

  DirectResolver({http.Client? client}) : _client = client ?? http.Client();

  static const _mediaExtensions = {
    'mp4', 'm4a', 'mp3', 'wav', 'webm', 'mov', 'flv', 'ogg', 'opus', 'aac', 'mkv'
  };

  @override
  bool supports(Uri url) {
    final path = url.path.toLowerCase();
    final ext = p.extension(path).replaceAll('.', '');
    return _mediaExtensions.contains(ext);
  }

  @override
  Future<MediaInfo> analyze(Uri url) async {
    final path = url.path;
    final filename = p.basename(path);
    final ext = p.extension(path).replaceAll('.', '').toLowerCase();

    // Probe headers with HEAD
    int? contentLength;
    try {
      final headRes = await _client.head(url);
      if (headRes.statusCode == 200) {
        final cl = headRes.headers['content-length'];
        if (cl != null) contentLength = int.tryParse(cl);
      }
    } catch (_) {}

    final isAudioOnly = ext == 'mp3' || ext == 'm4a' || ext == 'wav' || ext == 'ogg' || ext == 'opus' || ext == 'aac';

    final formats = <MediaFormat>[];
    if (isAudioOnly) {
      formats.add(MediaFormat(
        formatId: 'direct_audio',
        formatType: FormatType.audio,
        container: ext,
        audioCodec: ext,
        estimatedSizeBytes: contentLength,
        hasVideo: false,
        hasAudio: true,
        streamUrl: url,
        isBestAudio: true,
      ));
    } else {
      formats.add(MediaFormat(
        formatId: 'direct_video',
        formatType: FormatType.video,
        container: ext,
        resolution: 'Direct Source',
        estimatedSizeBytes: contentLength,
        videoCodec: ext,
        audioCodec: 'aac',
        hasVideo: true,
        hasAudio: true,
        streamUrl: url,
      ));
      formats.add(MediaFormat(
        formatId: 'direct_extracted_audio',
        formatType: FormatType.audio,
        container: 'm4a',
        audioCodec: 'aac',
        estimatedSizeBytes: contentLength != null ? (contentLength * 0.15).round() : null,
        hasVideo: false,
        hasAudio: true,
        streamUrl: url,
        isBestAudio: true,
      ));
    }

    return MediaInfo(
      platform: 'direct',
      mediaId: filename,
      title: filename.replaceAll('_', ' ').replaceAll('-', ' '),
      author: url.host,
      duration: const Duration(minutes: 3), // estimated default
      sourceUrl: url,
      formats: formats,
    );
  }

  @override
  Future<List<MediaFormat>> getFormats(Uri url) async {
    final info = await analyze(url);
    return info.formats;
  }
}
