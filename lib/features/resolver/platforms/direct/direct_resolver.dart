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

  static const _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'vi,en-US;q=0.9,en;q=0.8',
  };

  @override
  bool supports(Uri url) {
    // Phân giải vạn năng cho mọi đường dẫn HTTP/HTTPS hợp lệ
    return url.hasScheme && (url.scheme == 'http' || url.scheme == 'https');
  }

  @override
  Future<MediaInfo> analyze(Uri url) async {
    final host = url.host.toLowerCase();

    // 1. Kiểm tra các nền tảng đóng chỉ hoạt động trong ứng dụng di động
    if (host.contains('zalo.video') || host.contains('zalo.me')) {
      throw const FormatException(
        'Liên kết Zalo Video yêu cầu quét mã QR và mở trong ứng dụng Zalo (Zalo bảo mật và không hỗ trợ phát trực tiếp trên web).'
      );
    }

    final path = url.path;
    final ext = p.extension(path).replaceAll('.', '').toLowerCase();

    // 2. Nếu đuôi file là định dạng media phổ biến -> Tải trực tiếp
    if (_mediaExtensions.contains(ext)) {
      return await _analyzeDirectFile(url, ext, p.basename(path));
    }

    // 3. Nếu không có đuôi file rõ ràng, gửi request kiểm tra Content-Type
    http.Response? probeRes;
    try {
      final head = await _client.head(url, headers: _browserHeaders).timeout(const Duration(seconds: 6));
      if (head.statusCode == 200 || head.statusCode == 206) {
        final ct = (head.headers['content-type'] ?? '').toLowerCase();
        if (ct.startsWith('video/') || ct.startsWith('audio/')) {
          final guessedExt = _guessExtFromContentType(ct) ?? 'mp4';
          final cl = int.tryParse(head.headers['content-length'] ?? '');
          final name = p.basename(path).isEmpty ? 'Media_${DateTime.now().millisecondsSinceEpoch}' : p.basename(path);
          return _buildMediaInfo(url, guessedExt, name, cl);
        }
      }
    } catch (_) {}

    // 4. Nếu là trang web HTML, cào HTML để trích xuất thẻ video / OpenGraph
    try {
      probeRes = await _client.get(url, headers: _browserHeaders).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw FormatException('Không thể kết nối đến máy chủ: $e');
    }

    if (probeRes.statusCode >= 400) {
      throw FormatException('Máy chủ phản hồi mã lỗi HTTP ${probeRes.statusCode}');
    }

    final contentType = (probeRes.headers['content-type'] ?? '').toLowerCase();
    if (contentType.startsWith('video/') || contentType.startsWith('audio/')) {
      final guessedExt = _guessExtFromContentType(contentType) ?? 'mp4';
      final cl = probeRes.bodyBytes.length;
      final name = p.basename(path).isEmpty ? 'Media_${DateTime.now().millisecondsSinceEpoch}' : p.basename(path);
      return _buildMediaInfo(url, guessedExt, name, cl);
    }

    // Phân tích mã nguồn HTML
    return await _extractMediaFromHtml(url, probeRes.body);
  }

  Future<MediaInfo> _analyzeDirectFile(Uri url, String ext, String filename) async {
    int? contentLength;
    try {
      final headRes = await _client.head(url, headers: _browserHeaders).timeout(const Duration(seconds: 6));
      if (headRes.statusCode == 200) {
        final cl = headRes.headers['content-length'];
        if (cl != null) contentLength = int.tryParse(cl);
      }
    } catch (_) {}

    final safeName = filename.isEmpty ? 'Tệp_${DateTime.now().millisecondsSinceEpoch}' : filename;
    return _buildMediaInfo(url, ext, safeName, contentLength);
  }

  MediaInfo _buildMediaInfo(
    Uri streamUrl,
    String ext,
    String filename,
    int? contentLength, {
    String? pageTitle,
    String? thumbnail,
  }) {
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
        streamUrl: streamUrl,
        isBestAudio: true,
      ));
    } else {
      formats.add(MediaFormat(
        formatId: 'direct_video',
        formatType: FormatType.video,
        container: ext,
        resolution: 'Chất lượng gốc',
        estimatedSizeBytes: contentLength,
        videoCodec: ext,
        audioCodec: 'aac',
        hasVideo: true,
        hasAudio: true,
        streamUrl: streamUrl,
      ));
      formats.add(MediaFormat(
        formatId: 'direct_extracted_audio',
        formatType: FormatType.audio,
        container: 'm4a',
        audioCodec: 'aac',
        estimatedSizeBytes: contentLength != null ? (contentLength * 0.15).round() : null,
        hasVideo: false,
        hasAudio: true,
        streamUrl: streamUrl,
        isBestAudio: true,
      ));
    }

    final title = pageTitle ?? filename.replaceAll('_', ' ').replaceAll('-', ' ');

    return MediaInfo(
      platform: 'direct',
      mediaId: filename,
      title: title.isEmpty ? 'Video Web' : title,
      author: streamUrl.host,
      thumbnailUrl: thumbnail,
      duration: const Duration(minutes: 3),
      sourceUrl: streamUrl,
      formats: formats,
    );
  }

  Future<MediaInfo> _extractMediaFromHtml(Uri pageUrl, String html) async {
    // 1. Tìm tiêu đề trang
    String? title;
    final ogTitle = RegExp(r'''<meta\s+property=["']og:title["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html) ??
        RegExp(r'''<meta\s+content=["']([^"']+)["']\s+property=["']og:title["']''', caseSensitive: false).firstMatch(html);
    if (ogTitle != null) {
      title = ogTitle.group(1);
    } else {
      final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) title = titleMatch.group(1)?.trim();
    }

    // 2. Tìm ảnh thu nhỏ Thumbnail
    String? thumbnail;
    final ogImage = RegExp(r'''<meta\s+property=["']og:image(?::secure_url)?["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html) ??
        RegExp(r'''<meta\s+content=["']([^"']+)["']\s+property=["']og:image(?::secure_url)?["']''', caseSensitive: false).firstMatch(html);
    if (ogImage != null) {
      thumbnail = _resolveUrl(pageUrl, ogImage.group(1)!).toString();
    }

    // 3. Tìm luồng video trực tiếp
    String? videoUrlStr;

    // 3a. OpenGraph Video (og:video, og:video:url, og:video:secure_url)
    final ogVideo = RegExp(r'''<meta\s+property=["']og:video(?::secure_url|:url)?["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html) ??
        RegExp(r'''<meta\s+content=["']([^"']+)["']\s+property=["']og:video(?::secure_url|:url)?["']''', caseSensitive: false).firstMatch(html);
    if (ogVideo != null) {
      videoUrlStr = ogVideo.group(1);
    }

    // 3b. Twitter Player Stream
    if (videoUrlStr == null) {
      final twStream = RegExp(r'''<meta\s+name=["']twitter:player:stream["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
      if (twStream != null) videoUrlStr = twStream.group(1);
    }

    // 3c. Thẻ HTML5 <video src="...">
    if (videoUrlStr == null) {
      final vTag = RegExp(r'''<video[^>]+src=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
      if (vTag != null) videoUrlStr = vTag.group(1);
    }

    // 3d. Thẻ HTML5 <source src="...">
    if (videoUrlStr == null) {
      final sTag = RegExp(r'''<source[^>]+src=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
      if (sTag != null) videoUrlStr = sTag.group(1);
    }

    // 3e. JSON-LD hoặc dữ liệu nhúng contentUrl
    if (videoUrlStr == null) {
      final jsonMatch = RegExp(r'''["']contentUrl["']\s*:\s*["']([^"']+)["']''').firstMatch(html);
      if (jsonMatch != null) videoUrlStr = jsonMatch.group(1);
    }

    // 3f. Tìm liên kết .mp4 đầu tiên trong mã nguồn nếu có
    if (videoUrlStr == null) {
      final mp4Match = RegExp(r'''https?://[^"'<>\s]+\.mp4(?:\?[^"'<>\s]*)?''').firstMatch(html);
      if (mp4Match != null) videoUrlStr = mp4Match.group(0);
    }

    if (videoUrlStr == null || videoUrlStr.isEmpty) {
      throw const FormatException('Không tìm thấy luồng phát video hoặc âm thanh trực tiếp nào từ trang web này.');
    }

    final resolvedVideoUri = _resolveUrl(pageUrl, videoUrlStr);
    final ext = p.extension(resolvedVideoUri.path).replaceAll('.', '').toLowerCase();
    final safeExt = _mediaExtensions.contains(ext) ? ext : 'mp4';

    // Thử kiểm tra dung lượng qua HEAD
    int? contentLength;
    try {
      final head = await _client.head(resolvedVideoUri, headers: _browserHeaders).timeout(const Duration(seconds: 4));
      if (head.statusCode == 200) {
        contentLength = int.tryParse(head.headers['content-length'] ?? '');
      }
    } catch (_) {}

    return _buildMediaInfo(
      resolvedVideoUri,
      safeExt,
      p.basename(resolvedVideoUri.path),
      contentLength,
      pageTitle: title,
      thumbnail: thumbnail,
    );
  }

  Uri _resolveUrl(Uri base, String relativeOrAbsolute) {
    var raw = relativeOrAbsolute.replaceAll(r'\/', '/');
    if (raw.startsWith('//')) {
      return Uri.parse('${base.scheme}:$raw');
    }
    return base.resolve(raw);
  }

  String? _guessExtFromContentType(String contentType) {
    if (contentType.contains('mp4')) return 'mp4';
    if (contentType.contains('webm')) return 'webm';
    if (contentType.contains('mpeg') || contentType.contains('mp3')) return 'mp3';
    if (contentType.contains('m4a') || contentType.contains('aac')) return 'm4a';
    if (contentType.contains('ogg')) return 'ogg';
    if (contentType.contains('wav')) return 'wav';
    return null;
  }

  @override
  Future<List<MediaFormat>> getFormats(Uri url) async {
    final info = await analyze(url);
    return info.formats;
  }
}
