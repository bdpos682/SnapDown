import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_video/core/navigation/navigation_provider.dart';
import 'package:snap_video/features/downloads/domain/download_status.dart';
import 'package:snap_video/features/downloads/domain/download_task.dart';
import 'package:snap_video/features/resolver/domain/media_format.dart';
import 'package:snap_video/features/resolver/domain/media_info.dart';
import 'package:snap_video/features/resolver/domain/resolver_registry.dart';
import 'package:snap_video/features/resolver/platforms/direct/direct_resolver.dart';
import 'package:snap_video/features/resolver/platforms/facebook/facebook_resolver.dart';
import 'package:snap_video/features/resolver/platforms/instagram/instagram_resolver.dart';
import 'package:snap_video/features/resolver/platforms/tiktok/tiktok_resolver.dart';
import 'package:snap_video/features/resolver/platforms/twitter/twitter_resolver.dart';
import 'package:snap_video/features/resolver/platforms/vimeo/vimeo_resolver.dart';
import 'package:snap_video/features/resolver/platforms/youtube/youtube_resolver.dart';

void main() {
  group('ResolverRegistry Matching Tests', () {
    final registry = ResolverRegistry();

    test('Identifies YouTube URLs correctly', () {
      final yt1 = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      final yt2 = Uri.parse('https://youtu.be/dQw4w9WgXcQ');
      final yt3 = Uri.parse('https://www.youtube.com/shorts/dQw4w9WgXcQ');

      expect(registry.findResolver(yt1), isA<YoutubeResolver>());
      expect(registry.findResolver(yt2), isA<YoutubeResolver>());
      expect(registry.findResolver(yt3), isA<YoutubeResolver>());
    });

    test('Identifies TikTok URLs correctly', () {
      final tt1 = Uri.parse('https://www.tiktok.com/@creator/video/1234567890');
      final tt2 = Uri.parse('https://vt.tiktok.com/ZS1234567/');

      expect(registry.findResolver(tt1), isA<TiktokResolver>());
      expect(registry.findResolver(tt2), isA<TiktokResolver>());
    });

    test('Identifies Facebook URLs correctly', () {
      final fb1 = Uri.parse('https://www.facebook.com/watch/?v=123456');
      final fb2 = Uri.parse('https://fb.watch/abcdef123/');

      expect(registry.findResolver(fb1), isA<FacebookResolver>());
      expect(registry.findResolver(fb2), isA<FacebookResolver>());
    });

    test('Identifies Instagram URLs correctly', () {
      final ig1 = Uri.parse('https://www.instagram.com/reel/C8zX1y2/?igsh=abc');
      final ig2 = Uri.parse('https://www.instagram.com/p/C8zX1y2/');

      expect(registry.findResolver(ig1), isA<InstagramResolver>());
      expect(registry.findResolver(ig2), isA<InstagramResolver>());
    });

    test('Identifies Twitter / X URLs correctly', () {
      final tw = Uri.parse('https://twitter.com/user/status/1234567890');
      final x = Uri.parse('https://x.com/user/status/1234567890');

      expect(registry.findResolver(tw), isA<TwitterResolver>());
      expect(registry.findResolver(x), isA<TwitterResolver>());
    });

    test('Identifies Vimeo URLs correctly', () {
      final vim = Uri.parse('https://vimeo.com/76979871');
      expect(registry.findResolver(vim), isA<VimeoResolver>());
    });

    test('Identifies Direct media URLs correctly', () {
      final mp4 = Uri.parse('https://cdn.example.com/videos/sample.mp4');
      final mp3 = Uri.parse('https://cdn.example.com/music/track.mp3');

      expect(registry.findResolver(mp4), isA<DirectResolver>());
      expect(registry.findResolver(mp3), isA<DirectResolver>());
    });

    test('Throws UnsupportedPlatformException on unsupported URLs', () {
      final unsupported = Uri.parse('https://example.com/article/read-this');
      expect(
        () => registry.analyze(unsupported),
        throwsA(isA<UnsupportedPlatformException>()),
      );
    });
  });

  group('MediaFormat & DownloadTask Formatting Tests', () {
    test('MediaFormat display and size formatting', () {
      final format = MediaFormat(
        formatId: 'fmt_1080',
        formatType: FormatType.video,
        container: 'mp4',
        resolution: '1080p',
        fps: 60,
        estimatedSizeBytes: 52428800, // 50 MB
        hasVideo: true,
        hasAudio: false,
        audioStreamUrl: Uri.parse('https://example.com/audio'),
        streamUrl: Uri.parse('https://example.com/video'),
      );

      expect(format.isAdaptive, isTrue);
      expect(format.formattedSize, '50.0 MB');
      expect(format.displayQuality, '1080p');
    });

    test('DownloadTask speed, ETA, and progress calculation', () {
      final dummyInfo = MediaInfo(
        platform: 'youtube',
        mediaId: 'dummy123',
        title: 'Test Title',
        author: 'Test Author',
        duration: const Duration(minutes: 3),
        sourceUrl: Uri.parse('https://youtube.com/watch?v=dummy123'),
        formats: [],
      );

      final dummyFormat = MediaFormat(
        formatId: 'audio_best',
        formatType: FormatType.audio,
        container: 'm4a',
        hasVideo: false,
        hasAudio: true,
        streamUrl: Uri.parse('https://example.com/audio.m4a'),
        isBestAudio: true,
      );

      final task = DownloadTask(
        id: 'task_001',
        mediaInfo: dummyInfo,
        selectedFormat: dummyFormat,
        status: DownloadStatus.downloading,
        downloadedBytes: 5242880, // 5 MB
        totalBytes: 10485760, // 10 MB
        progress: 0.5,
        speedBytesPerSec: 1048576, // 1 MB/s
        etaSeconds: 5,
      );

      expect(task.formattedProgress, '50.0%');
      expect(task.formattedSpeed, '1.0 MB/s');
      expect(task.formattedEta, '5s');
      expect(task.formattedDownloadedSize, '5.0 MB');
      expect(task.formattedTotalSize, '10.0 MB');
    });
  });

  group('Navigation & Tab Switch Tests', () {
    test('NavigationTabNotifier switches tabs properly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navigationTabProvider), 0);

      container.read(navigationTabProvider.notifier).switchToDownloads();
      expect(container.read(navigationTabProvider), 1);

      container.read(navigationTabProvider.notifier).switchToMusic();
      expect(container.read(navigationTabProvider), 2);

      container.read(navigationTabProvider.notifier).switchToVideo();
      expect(container.read(navigationTabProvider), 3);

      container.read(navigationTabProvider.notifier).switchToHome();
      expect(container.read(navigationTabProvider), 0);
    });
  });
}
