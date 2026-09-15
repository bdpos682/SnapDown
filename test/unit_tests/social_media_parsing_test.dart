import 'package:flutter_test/flutter_test.dart';
import 'package:snap_video/features/resolver/domain/media_format.dart';
import 'package:snap_video/features/resolver/domain/media_info.dart';
import 'package:snap_video/features/resolver/platforms/facebook/facebook_resolver.dart';
import 'package:snap_video/features/resolver/platforms/instagram/instagram_resolver.dart';
import 'package:snap_video/features/resolver/platforms/tiktok/tiktok_resolver.dart';
import 'package:snap_video/features/resolver/platforms/twitter/twitter_resolver.dart';
import 'package:snap_video/features/resolver/platforms/direct/direct_resolver.dart';
import 'package:snap_video/features/resolver/domain/resolver_registry.dart';

void main() {
  group('Social Media Resolver Tests (TikTok, Facebook)', () {
    test('TikTok Resolver matches short and standard URLs', () {
      final resolver = TiktokResolver();
      expect(resolver.supports(Uri.parse('https://www.tiktok.com/@creator/video/7123456789012345678')), isTrue);
      expect(resolver.supports(Uri.parse('https://vt.tiktok.com/ZS2345678/')), isTrue);
      expect(resolver.supports(Uri.parse('https://vm.tiktok.com/ZM1234567/')), isTrue);
      expect(resolver.supports(Uri.parse('https://youtube.com/watch?v=123')), isFalse);
    });

    test('Facebook Resolver matches FB Watch, fb.me, and standard watch URLs', () {
      final resolver = FacebookResolver();
      expect(resolver.supports(Uri.parse('https://www.facebook.com/watch/?v=9876543210')), isTrue);
      expect(resolver.supports(Uri.parse('https://fb.watch/k8y9z0/')), isTrue);
      expect(resolver.supports(Uri.parse('https://www.facebook.com/reel/123456789')), isTrue);
      expect(resolver.supports(Uri.parse('https://tiktok.com/@abc')), isFalse);
    });

    test('TikTok format structures properly support both Video and Audio extractions', () {
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
          streamUrl: Uri.parse('https://v16-webapp-prime.tiktok.com/video/sample.mp4'),
        ),
        MediaFormat(
          formatId: 'tiktok_audio',
          formatType: FormatType.audio,
          container: 'm4a',
          audioCodec: 'aac',
          bitrate: 128000,
          hasVideo: false,
          hasAudio: true,
          streamUrl: Uri.parse('https://v16-webapp-prime.tiktok.com/video/sample.mp4'),
          isBestAudio: true,
        ),
      ];

      final info = MediaInfo(
        platform: 'tiktok',
        mediaId: '7123456789012345678',
        title: 'TikTok Viral Clip',
        author: 'Creator',
        duration: const Duration(seconds: 45),
        sourceUrl: Uri.parse('https://www.tiktok.com/@creator/video/7123456789012345678'),
        formats: formats,
      );

      expect(info.videoFormats.length, 1);
      expect(info.audioFormats.length, 1);
      expect(info.bestAudio, isNotNull);
      expect(info.highestQualityVideo?.resolution, '1080p');
    });

    test('Facebook format structures properly provide HD and SD formats with AAC audio extraction', () {
      final formats = <MediaFormat>[
        MediaFormat(
          formatId: 'fb_hd',
          formatType: FormatType.video,
          container: 'mp4',
          resolution: '720p HD',
          height: 720,
          videoCodec: 'h264',
          audioCodec: 'aac',
          hasVideo: true,
          hasAudio: true,
          streamUrl: Uri.parse('https://video.xx.fbcdn.net/v/sample_hd.mp4'),
        ),
        MediaFormat(
          formatId: 'fb_audio',
          formatType: FormatType.audio,
          container: 'm4a',
          audioCodec: 'aac',
          bitrate: 128000,
          hasVideo: false,
          hasAudio: true,
          streamUrl: Uri.parse('https://video.xx.fbcdn.net/v/sample_hd.mp4'),
          isBestAudio: true,
        ),
      ];

      final info = MediaInfo(
        platform: 'facebook',
        mediaId: '9876543210',
        title: 'Facebook Livestream Highlight',
        author: 'FB Page',
        duration: const Duration(minutes: 2),
        sourceUrl: Uri.parse('https://fb.watch/sample/'),
        formats: formats,
      );

      expect(info.videoFormats.length, 1);
      expect(info.audioFormats.length, 1);
      expect(info.audioFormats.first.audioCodec, 'aac');
    });

    test('Instagram Reel Resolver resolves reel link with video and audio streams', () async {
      final igResolver = InstagramResolver();
      final igUri = Uri.parse('https://www.instagram.com/reel/DZ8EQEVzl3k/?stkn=ZXprMGRkemUwbjF1');
      expect(igResolver.supports(igUri), isTrue);

      final igInfo = await igResolver.analyze(igUri);
      expect(igInfo.platform, 'instagram');
      expect(igInfo.mediaId, 'DZ8EQEVzl3k');
      expect(igInfo.formats.isNotEmpty, isTrue);
      expect(igInfo.videoFormats.isNotEmpty, isTrue);
      expect(igInfo.audioFormats.isNotEmpty, isTrue);
      expect(igInfo.formats.first.streamUrl.toString(), startsWith('https://'));
    });

    test('Twitter/X Resolver extracts video variants and audio formats with resolutions', () async {
      final twResolver = TwitterResolver();
      final xUri = Uri.parse('https://x.com/Lor_idol/status/2097855805928382506/video/1?s=46');
      expect(twResolver.supports(xUri), isTrue);

      final twInfo = await twResolver.analyze(xUri);
      expect(twInfo.platform, 'twitter');
      expect(twInfo.mediaId, '2097855805928382506');
      expect(twInfo.formats.length, greaterThanOrEqualTo(2));
      expect(twInfo.videoFormats.isNotEmpty, isTrue);
      expect(twInfo.bestAudio, isNotNull);
      expect(twInfo.videoFormats.first.resolution, contains('p'));
    });

    test('DirectResolver supports universal HTTP/HTTPS links and gives friendly message for Zalo Video', () async {
      final directResolver = DirectResolver();
      final zaloUri = Uri.parse('https://zalo.video/s/SgZ3eHUtX');
      expect(directResolver.supports(zaloUri), isTrue);

      expect(
        () => directResolver.analyze(zaloUri),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Zalo Video'),
        )),
      );
    });

    test('ResolverRegistry properly routes Instagram, Twitter/X, and Zalo/Direct URLs', () async {
      final registry = ResolverRegistry();

      // 1. Instagram
      final igInfo = await registry.analyze(Uri.parse('https://www.instagram.com/reel/DZ8EQEVzl3k/?stkn=ZXprMGRkemUwbjF1'));
      expect(igInfo.platform, 'instagram');
      expect(igInfo.formats.isNotEmpty, isTrue);

      // 2. Twitter / X
      final twInfo = await registry.analyze(Uri.parse('https://x.com/Lor_idol/status/2097855805928382506/video/1?s=46'));
      expect(twInfo.platform, 'twitter');
      expect(twInfo.formats.isNotEmpty, isTrue);

      // 3. Zalo Video through Registry
      expect(
        () => registry.analyze(Uri.parse('https://zalo.video/s/SgZ3eHUtX')),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Zalo Video'),
        )),
      );
    });
  });
}
