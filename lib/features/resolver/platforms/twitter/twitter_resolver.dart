import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
      throw FormatException('Liên kết X (Twitter) không hợp lệ: $url');
    }

    // 1. Thử phân giải qua FxTwitter API tốc độ cao, hỗ trợ trích xuất video đầy đủ
    try {
      final info = await _analyzeViaFxTwitter(tweetId, url);
      if (info != null && info.formats.isNotEmpty) {
        return info;
      }
    } catch (e) {
      debugPrint('FxTwitter API lỗi: $e. Đang chuyển sang phương thức dự phòng Twimg...');
    }

    // 2. Dự phòng: Phân giải qua Twimg Syndication API
    return await _analyzeViaSyndication(tweetId, url);
  }

  Future<MediaInfo?> _analyzeViaFxTwitter(String tweetId, Uri originalUrl) async {
    final fxUrl = Uri.parse('https://api.fxtwitter.com/status/$tweetId');
    final response = await _client.get(
      fxUrl,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['code'] != 200 || data['tweet'] == null) return null;

    final tweet = data['tweet'] as Map<String, dynamic>;
    final text = tweet['text'] as String? ?? 'Bài viết X';
    final authorMap = tweet['author'] as Map<String, dynamic>?;
    final authorName = authorMap?['name'] as String? ?? authorMap?['screen_name'] as String? ?? 'X Creator';

    final media = tweet['media'] as Map<String, dynamic>?;
    final videos = media?['videos'] as List<dynamic>?;
    if (videos == null || videos.isEmpty) return null;

    final firstVideo = videos.first as Map<String, dynamic>;
    final thumbnail = firstVideo['thumbnail_url'] as String?;
    final durationSec = (firstVideo['duration'] as num?)?.toDouble() ?? 45.0;

    final rawVariants = firstVideo['variants'] as List<dynamic>? ?? [];
    final mp4List = <Map<String, dynamic>>[];

    for (final v in rawVariants) {
      if (v is! Map<String, dynamic>) continue;
      final cType = (v['content_type'] as String? ?? v['type'] as String? ?? '').toLowerCase();
      final urlStr = v['url'] as String? ?? v['src'] as String? ?? '';
      if (cType.contains('mp4') || urlStr.contains('.mp4')) {
        mp4List.add(v);
      }
    }

    final formats = <MediaFormat>[];

    if (mp4List.isNotEmpty) {
      // Sắp xếp theo bitrate giảm dần
      mp4List.sort((a, b) {
        final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
        final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
        return brB.compareTo(brA);
      });

      for (int i = 0; i < mp4List.length; i++) {
        final v = mp4List[i];
        final src = v['url'] as String? ?? v['src'] as String?;
        if (src == null || src.isEmpty) continue;

        final bitrate = (v['bitrate'] as num?)?.toInt();
        final res = _formatResolution(null, null, src);

        formats.add(MediaFormat(
          formatId: 'x_video_$i',
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
    } else {
      // Dùng URL chính của video
      final mainVideoUrl = firstVideo['url'] as String?;
      if (mainVideoUrl != null && mainVideoUrl.isNotEmpty) {
        final w = (firstVideo['width'] as num?)?.toInt();
        final h = (firstVideo['height'] as num?)?.toInt();
        final res = _formatResolution(w, h, mainVideoUrl);

        formats.add(MediaFormat(
          formatId: 'x_video_0',
          formatType: FormatType.video,
          container: 'mp4',
          resolution: res,
          width: w,
          height: h,
          videoCodec: 'h264',
          audioCodec: 'aac',
          hasVideo: true,
          hasAudio: true,
          streamUrl: Uri.parse(mainVideoUrl),
        ));
      }
    }

    if (formats.isEmpty) return null;

    // Định dạng tách nhạc chất lượng cao
    final bestStream = formats.first.streamUrl;
    formats.add(MediaFormat(
      formatId: 'x_audio',
      formatType: FormatType.audio,
      container: 'm4a',
      audioCodec: 'aac',
      bitrate: 128000,
      hasVideo: false,
      hasAudio: true,
      streamUrl: bestStream,
      isBestAudio: true,
    ));

    return MediaInfo(
      platform: 'twitter',
      mediaId: tweetId,
      title: text.length > 65 ? '${text.substring(0, 65)}...' : text,
      author: authorName,
      thumbnailUrl: thumbnail,
      duration: Duration(seconds: durationSec.round()),
      sourceUrl: originalUrl,
      formats: formats,
    );
  }

  Future<MediaInfo> _analyzeViaSyndication(String tweetId, Uri originalUrl) async {
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
      throw FormatException('Không thể tải dữ liệu bài viết X (Twitter): HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['text'] as String? ?? 'Bài viết X';
    final user = data['user'] as Map<String, dynamic>?;
    final authorName = user?['name'] as String? ?? 'X Creator';

    // Tìm video media trong mediaDetails hoặc video
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
      throw FormatException('Không tìm thấy luồng video trong bài viết X: $originalUrl');
    }

    // Lọc các định dạng MP4 và hỗ trợ cả type/content_type và src/url
    final mp4Variants = variants.where((v) {
      if (v is! Map<String, dynamic>) return false;
      final cType = (v['content_type'] as String? ?? v['type'] as String? ?? '').toLowerCase();
      final src = (v['src'] as String? ?? v['url'] as String? ?? '');
      return cType.contains('mp4') || src.contains('.mp4');
    }).toList();

    mp4Variants.sort((a, b) {
      final brA = (a['bitrate'] as num?)?.toInt() ?? 0;
      final brB = (b['bitrate'] as num?)?.toInt() ?? 0;
      return brB.compareTo(brA);
    });

    if (mp4Variants.isEmpty) {
      throw FormatException('Không tìm thấy luồng MP4 tương thích trong bài viết X: $originalUrl');
    }

    final formats = <MediaFormat>[];
    for (int i = 0; i < mp4Variants.length; i++) {
      final v = mp4Variants[i];
      final src = v['src'] as String? ?? v['url'] as String?;
      if (src == null || src.isEmpty) continue;

      final bitrate = (v['bitrate'] as num?)?.toInt();
      final res = _formatResolution(null, null, src);

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
      title: text.length > 65 ? '${text.substring(0, 65)}...' : text,
      author: authorName,
      thumbnailUrl: thumbnail,
      duration: const Duration(seconds: 45),
      sourceUrl: originalUrl,
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
    final match = RegExp(r'/status(?:es)?/(\d+)').firstMatch(url.toString());
    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  String _formatResolution(int? width, int? height, String? url) {
    if (width != null && height != null && width > 0 && height > 0) {
      final minDim = math.min(width, height);
      return '${minDim}p';
    }
    if (url != null) {
      final match = RegExp(r'/(\d+)x(\d+)/').firstMatch(url);
      if (match != null) {
        final w = int.tryParse(match.group(1)!);
        final h = int.tryParse(match.group(2)!);
        if (w != null && h != null && w > 0 && h > 0) {
          return '${math.min(w, h)}p';
        }
      }
    }
    return 'HD';
  }
}
