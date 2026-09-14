// ignore_for_file: avoid_print
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:snap_video/features/resolver/platforms/direct/direct_resolver.dart';
import 'package:snap_video/features/resolver/platforms/youtube/youtube_resolver.dart';
import 'package:test/test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

void main() {

  final tempFilesToClean = <File>[];

  tearDownAll(() {
    for (final file in tempFilesToClean) {
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
  });

  group('E2E Real Video & Audio Download Tests', () {
    test('YouTube: Analyze and download real video stream to disk', () async {
      final resolver = YoutubeResolver();
      final url = Uri.parse('https://www.youtube.com/watch?v=jNQXAC9IVRw'); // First YouTube video: "Me at the zoo"
      
      final mediaInfo = await resolver.analyze(url);
      expect(mediaInfo.title, isNotEmpty);
      expect(mediaInfo.formats, isNotEmpty);

      // Verify cached manifest exists
      final cachedManifest = YoutubeResolver.getCachedManifest(mediaInfo.mediaId);
      expect(cachedManifest, isNotNull);

      // Find lowest resolution video for fast test execution
      final videoFormat = mediaInfo.videoFormats.last;
      expect(videoFormat.hasVideo, isTrue);

      // Download first 128KB of video to disk
      final tempVideoFile = File('${Directory.systemTemp.path}/test_yt_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      tempFilesToClean.add(tempVideoFile);

      final ytClient = yt.YoutubeExplode();
      try {
        final streamInfo = cachedManifest!.video.firstWhere((s) => s.tag == int.tryParse(videoFormat.formatId.replaceAll('yt_', '')));
        final stream = ytClient.videos.streamsClient.get(streamInfo);
        final sink = tempVideoFile.openWrite();
        int bytes = 0;
        await for (final chunk in stream) {
          sink.add(chunk);
          bytes += chunk.length;
          if (bytes >= 1024 * 128) break; // 128 KB
        }
        await sink.flush();
        await sink.close();

        expect(tempVideoFile.existsSync(), isTrue);
        expect(tempVideoFile.lengthSync(), greaterThanOrEqualTo(1024 * 128));
        print('✅ YouTube Video Download Passed: ${tempVideoFile.path} (${tempVideoFile.lengthSync()} bytes)');
      } finally {
        ytClient.close();
      }
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('YouTube: Analyze and download real audio stream to disk (Muxed Fallback)', () async {
      final resolver = YoutubeResolver();
      final url = Uri.parse('https://www.youtube.com/watch?v=jNQXAC9IVRw');
      
      final mediaInfo = await resolver.analyze(url);
      final cachedManifest = YoutubeResolver.getCachedManifest(mediaInfo.mediaId);
      expect(cachedManifest, isNotNull);

      // Download audio stream from muxed stream tag 18
      final muxedStream = cachedManifest!.muxed.firstWhere((m) => m.tag == 18, orElse: () => cachedManifest.muxed.first);
      final tempAudioFile = File('${Directory.systemTemp.path}/test_yt_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      tempFilesToClean.add(tempAudioFile);

      final ytClient = yt.YoutubeExplode();
      try {
        final stream = ytClient.videos.streamsClient.get(muxedStream);
        final sink = tempAudioFile.openWrite();
        int bytes = 0;
        await for (final chunk in stream) {
          sink.add(chunk);
          bytes += chunk.length;
          if (bytes >= 1024 * 64) break; // 64 KB
        }
        await sink.flush();
        await sink.close();

        expect(tempAudioFile.existsSync(), isTrue);
        expect(tempAudioFile.lengthSync(), greaterThanOrEqualTo(1024 * 64));
        print('✅ YouTube Audio Download Passed: ${tempAudioFile.path} (${tempAudioFile.lengthSync()} bytes)');
      } finally {
        ytClient.close();
      }
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('Direct / Web: Analyze and download real MP4 video', () async {
      final resolver = DirectResolver();
      final url = Uri.parse('https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4');
      
      final mediaInfo = await resolver.analyze(url);
      expect(mediaInfo.formats, isNotEmpty);
      expect(mediaInfo.videoFormats.isNotEmpty, isTrue);

      final format = mediaInfo.videoFormats.first;
      final tempFile = File('${Directory.systemTemp.path}/test_direct_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      tempFilesToClean.add(tempFile);

      final client = http.Client();
      try {
        final req = http.Request('GET', format.streamUrl);
        req.headers['User-Agent'] = 'Mozilla/5.0';
        req.headers['Range'] = 'bytes=0-65535'; // 64 KB
        final resp = await client.send(req);
        final sink = tempFile.openWrite();
        await for (final chunk in resp.stream) {
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();

        expect(tempFile.existsSync(), isTrue);
        expect(tempFile.lengthSync(), greaterThanOrEqualTo(65536));
        print('✅ Direct Video Download Passed: ${tempFile.path} (${tempFile.lengthSync()} bytes)');
      } finally {
        client.close();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Direct / Web: Analyze and download real MP3 audio', () async {
      final resolver = DirectResolver();
      final url = Uri.parse('https://interactive-examples.mdn.mozilla.net/media/cc0-audio/t-rex-roar.mp3');
      
      final mediaInfo = await resolver.analyze(url);
      expect(mediaInfo.formats, isNotEmpty);

      final format = mediaInfo.formats.first;
      final tempAudio = File('${Directory.systemTemp.path}/test_direct_audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
      tempFilesToClean.add(tempAudio);

      final client = http.Client();
      try {
        final req = http.Request('GET', format.streamUrl);
        req.headers['User-Agent'] = 'Mozilla/5.0';
        final resp = await client.send(req);
        final sink = tempAudio.openWrite();
        await for (final chunk in resp.stream) {
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();

        expect(tempAudio.existsSync(), isTrue);
        expect(tempAudio.lengthSync(), greaterThan(10000));
        print('✅ Direct Audio Download Passed: ${tempAudio.path} (${tempAudio.lengthSync()} bytes)');
      } finally {
        client.close();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
