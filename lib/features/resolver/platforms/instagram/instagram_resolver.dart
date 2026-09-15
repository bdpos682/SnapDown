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
    return host.contains('instagram.com') || host.contains('instagr.am');
  }

  @override
  Future<MediaInfo> analyze(Uri url) async {
    final shortcode = _extractShortcode(url);
    if (shortcode == null) {
      throw FormatException('Đường dẫn Instagram không hợp lệ: $url');
    }

    final isReel = url.path.contains('/reel/') || url.path.contains('/reels/');
    final primaryType = isReel ? 'reel' : 'p';
    final secondaryType = isReel ? 'p' : 'reel';

    // Thử trích xuất qua embed theo loại nội dung ưu tiên (reel trước cho video ngắn, p cho bài viết thông thường)
    String? html;
    for (final type in [primaryType, secondaryType]) {
      try {
        final embedUrl = Uri.parse('https://www.instagram.com/$type/$shortcode/embed/captioned/');
        final response = await _client.get(
          embedUrl,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 && response.body.contains('video_url')) {
          html = response.body;
          break;
        } else if (response.statusCode == 200 && html == null) {
          html = response.body;
        }
      } catch (_) {}
    }

    if (html == null) {
      throw FormatException('Không thể tải dữ liệu Instagram cho: $url');
    }

    // 1. Tìm video_url từ HTML hoặc cấu trúc JSON nhúng
    String? videoUrl = _extractVideoUrl(html);

    if (videoUrl == null) {
      throw FormatException('Không tìm thấy luồng video nào trong liên kết Instagram: $url');
    }

    // 2. Tìm ảnh thumbnail
    String? thumbnail = _extractThumbnailUrl(html);

    // 3. Tìm chú thích / Tiêu đề
    String? title = _extractCaption(html);

    // 4. Tìm tác giả
    String? author = _extractAuthor(html);

    // 5. Tìm kích thước khung hình
    int width = 1080;
    int height = 1920;
    final dimMatch = RegExp(r'\\?"dimensions\\?"\s*:\s*\{[^}]*\\?"height\\?"\s*:\s*(\d+)[^}]*\\?"width\\?"\s*:\s*(\d+)').firstMatch(html) ??
        RegExp(r'"dimensions"\s*:\s*\{[^}]*"height"\s*:\s*(\d+)[^}]*"width"\s*:\s*(\d+)').firstMatch(html);
    if (dimMatch != null) {
      height = int.tryParse(dimMatch.group(1)!) ?? height;
      width = int.tryParse(dimMatch.group(2)!) ?? width;
    }

    final resolutionLabel = height >= 1080 ? '1080p' : (height >= 720 ? '720p' : '${height}p');

    final formats = <MediaFormat>[
      MediaFormat(
        formatId: 'ig_video_hd',
        formatType: FormatType.video,
        container: 'mp4',
        resolution: resolutionLabel,
        width: width,
        height: height,
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
      title: title != null && title.isNotEmpty
          ? (title.length > 60 ? '${title.substring(0, 60)}...' : title)
          : 'Instagram Video',
      author: author ?? 'Instagram Creator',
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

  String? _extractVideoUrl(String html) {
    final match = RegExp(r'\\?"video_url\\?"\s*:\s*\\?"([^"]+?)(?:\\?"|")').firstMatch(html) ??
        RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(html) ??
        RegExp(r'<video[^>]+src="([^">]+)"').firstMatch(html);

    if (match == null) return null;
    return _cleanInstagramUrl(match.group(1)!);
  }

  String? _extractThumbnailUrl(String html) {
    final match = RegExp(r'\\?"display_url\\?"\s*:\s*\\?"([^"]+?)(?:\\?"|")').firstMatch(html) ??
        RegExp(r'"display_url"\s*:\s*"([^"]+)"').firstMatch(html) ??
        RegExp(r'<img[^>]+class="EmbeddedMediaImage"[^>]+src="([^">]+)"').firstMatch(html) ??
        RegExp(r'<meta[^>]+property="og:image"[^>]+content="([^">]+)"').firstMatch(html);

    if (match == null) return null;
    return _cleanInstagramUrl(match.group(1)!);
  }

  String? _extractCaption(String html) {
    // Caption từ JSON nhúng
    final textMatch = RegExp(r'\\?"edge_media_to_caption\\?"\s*:\s*\{[^}]*\\?"text\\?"\s*:\s*\\?"([^"\\]+)').firstMatch(html);
    if (textMatch != null) {
      return textMatch.group(1)?.replaceAll(r'\n', ' ').trim();
    }

    // Caption từ HTML div
    final captionMatch = RegExp(r'<div class="Caption"[^>]*>(.*?)<\/div>', dotAll: true).firstMatch(html);
    if (captionMatch != null) {
      return captionMatch.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }

    return null;
  }

  String? _extractAuthor(String html) {
    final authorMatch = RegExp(r'\\?"username\\?"\s*:\s*\\?"([^"\\]+)').firstMatch(html) ??
        RegExp(r'<a[^>]+class="CaptionUsername"[^>]*>(.*?)<\/a>').firstMatch(html);
    if (authorMatch != null) {
      return authorMatch.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
    return null;
  }

  String _cleanInstagramUrl(String raw) {
    return raw
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u00253D', '%3D')
        .replaceAll(r'\\u00253D', '%3D')
        .replaceAll(r'\\', '')
        .trim();
  }

  String? _extractShortcode(Uri url) {
    final segments = url.pathSegments;
    for (int i = 0; i < segments.length; i++) {
      if (segments[i] == 'p' || segments[i] == 'reel' || segments[i] == 'reels' || segments[i] == 'tv') {
        if (i + 1 < segments.length) return segments[i + 1];
      }
    }
    return segments.isNotEmpty ? segments.first : null;
  }
}
