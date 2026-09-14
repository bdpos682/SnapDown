import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../../core/database/models/media_item_model.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/storage/storage_manager.dart';
import '../../resolver/domain/media_format.dart';
import '../../resolver/domain/media_info.dart';
import '../../resolver/platforms/youtube/youtube_resolver.dart';
import '../domain/download_status.dart';
import '../domain/download_task.dart';
import 'media_processor.dart';

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;

  final MediaRepository _repository;
  final StorageManager _storage;
  final MediaProcessor _processor;
  final _uuid = const Uuid();
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  final http.Client _httpClient = http.Client();

  final List<DownloadTask> _tasks = [];
  final _tasksController = StreamController<List<DownloadTask>>.broadcast();

  final int _maxConcurrent = 2;
  int _activeCount = 0;

  DownloadManager._internal({
    MediaRepository? repository,
    StorageManager? storage,
    MediaProcessor? processor,
  })  : _repository = repository ?? MediaRepository(),
        _storage = storage ?? StorageManager(),
        _processor = processor ?? MediaProcessor();

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  Stream<List<DownloadTask>> get tasksStream => _tasksController.stream;

  void _notify() {
    if (!_tasksController.isClosed) {
      _tasksController.add(List.unmodifiable(_tasks));
    }
  }

  /// Đưa tác vụ tải mới vào hàng đợi
  DownloadTask enqueue({
    required MediaInfo mediaInfo,
    required MediaFormat selectedFormat,
    bool convertToMp3 = false,
    int? mp3Bitrate,
  }) {
    final task = DownloadTask(
      id: _uuid.v4(),
      mediaInfo: mediaInfo,
      selectedFormat: selectedFormat,
      convertToMp3: convertToMp3,
      mp3Bitrate: mp3Bitrate,
      statusMessage: 'Chờ trong hàng đợi',
    );

    _tasks.insert(0, task);
    _notify();
    _processQueue();
    return task;
  }

  void _processQueue() {
    if (_activeCount >= _maxConcurrent) return;

    for (final task in _tasks) {
      if (task.status == DownloadStatus.queued) {
        _activeCount++;
        _startTask(task);
        if (_activeCount >= _maxConcurrent) break;
      }
    }
  }

  Future<void> _startTask(DownloadTask task) async {
    await _storage.init();
    final info = task.mediaInfo;
    final format = task.selectedFormat;

    DateTime lastSpeedTime = DateTime.now();
    int lastDownloadedBytes = 0;

    void updateProgress(int current, int total, {String? customStatus}) {
      final now = DateTime.now();
      final elapsedMs = now.difference(lastSpeedTime).inMilliseconds;
      if (elapsedMs >= 400) {
        final bytesDelta = current - lastDownloadedBytes;
        task.speedBytesPerSec = (bytesDelta / (elapsedMs / 1000)).round();
        if (task.speedBytesPerSec > 0 && total > current) {
          task.etaSeconds = (total - current) ~/ task.speedBytesPerSec;
        }
        lastSpeedTime = now;
        lastDownloadedBytes = current;
      }

      task.downloadedBytes = current;
      task.totalBytes = total;
      task.progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
      if (customStatus != null) task.statusMessage = customStatus;
      _notify();
    }

    try {
      task.status = DownloadStatus.downloading;
      task.statusMessage = 'Đang bắt đầu tải...';
      _notify();

      String finalDestinationPath;

      if (info.platform == 'youtube') {
        finalDestinationPath = await _downloadYouTube(task, updateProgress);
      } else {
        finalDestinationPath = await _downloadGenericPlatform(task, updateProgress);
      }

      // Tải ảnh thu nhỏ (Thumbnail) về máy
      String? localThumbPath;
      if (info.thumbnailUrl != null) {
        try {
          localThumbPath = _storage.generateArtworkPath(extension: 'jpg');
          final thumbRes = await _httpClient.get(Uri.parse(info.thumbnailUrl!));
          if (thumbRes.statusCode == 200) {
            await File(localThumbPath).writeAsBytes(thumbRes.bodyBytes);
          } else {
            localThumbPath = null;
          }
        } catch (_) {
          localThumbPath = null;
        }
      }

      final file = File(finalDestinationPath);
      final fileSize = await file.length();

      // Lưu trữ bản ghi vào SQLite Database
      final mediaItem = MediaItemModel(
        id: task.id,
        sourceUrl: info.sourceUrl.toString(),
        sourcePlatform: info.platform,
        remoteId: info.mediaId,
        title: info.title,
        artist: info.author,
        description: info.description,
        mediaType: format.formatType == FormatType.audio ? 'audio' : 'video',
        localPath: finalDestinationPath,
        thumbnailPath: localThumbPath,
        thumbnailUrl: info.thumbnailUrl,
        durationMs: info.duration.inMilliseconds,
        audioCodec: format.audioCodec,
        videoCodec: format.videoCodec,
        container: format.container,
        bitrate: format.bitrate,
        width: format.width,
        height: format.height,
        fps: format.fps,
        fileSize: fileSize,
        downloadedAt: DateTime.now(),
      );

      await _repository.insertMedia(mediaItem);

      task.finalLocalPath = finalDestinationPath;
      task.status = DownloadStatus.completed;
      task.statusMessage = 'Hoàn tất tải về';
      task.progress = 1.0;
      _notify();
    } catch (e, stack) {
      debugPrint('Lỗi tải tệp: $e\n$stack');
      task.status = DownloadStatus.failed;
      task.statusMessage = 'Thất bại';
      task.errorMessage = e.toString();
      _notify();

      // Dọn dẹp tệp tạm thời
      for (final tmp in task.tempFiles) {
        await _storage.deleteFile(tmp);
      }
    } finally {
      _activeCount = (_activeCount - 1).clamp(0, 999);
      _processQueue();
    }
  }

  /// Tải chuyên biệt cho YouTube dùng manifest cache, watchdog stream và fallback muxed
  Future<String> _downloadYouTube(
    DownloadTask task,
    void Function(int current, int total, {String? customStatus}) updateProgress,
  ) async {
    final info = task.mediaInfo;
    final format = task.selectedFormat;

    task.statusMessage = 'Đang chuẩn bị luồng YouTube...';
    _notify();

    // 1. Tận dụng StreamManifest đã lưu trong cache từ bước phân tích (tránh bị YouTube rate limit)
    yt.StreamManifest? manifest = YoutubeResolver.getCachedManifest(info.mediaId);
    if (manifest == null) {
      task.statusMessage = 'Đang phân giải luồng YouTube...';
      _notify();
      try {
        manifest = await _yt.videos.streamsClient
            .getManifest(info.mediaId)
            .timeout(const Duration(seconds: 12));
        YoutubeResolver.cacheManifest(info.mediaId, manifest);
      } catch (e) {
        debugPrint('Lỗi tải manifest YouTube: $e');
      }
    }

    if (manifest == null) {
      throw Exception('Không thể phân giải danh sách luồng YouTube cho video này');
    }
    final validManifest = manifest;

    if (format.isAdaptive) {
      // Tìm stream video tương ứng
      final itagStr = format.formatId.replaceAll('yt_', '');
      final itag = int.tryParse(itagStr);
      final videoStream = validManifest.video.firstWhere(
        (s) => s.tag == itag,
        orElse: () => validManifest.video.first,
      );

      // Tìm stream audio tốt nhất
      final audioStream = validManifest.audioOnly.withHighestBitrate();

      final videoExt = videoStream.container.name;
      final audioExt = audioStream.container.name;

      final videoTmp = _storage.generateTempPath(prefix: 'v_${task.id}', extension: videoExt);
      final audioTmp = _storage.generateTempPath(prefix: 'a_${task.id}', extension: audioExt);
      task.tempFiles.addAll([videoTmp, audioTmp]);

      final totalCombinedBytes = videoStream.size.totalBytes + audioStream.size.totalBytes;
      int cumulativeDownloaded = 0;

      // 1. Tải luồng Video
      task.statusMessage = 'Đang tải luồng Video (${format.displayQuality})...';
      _notify();

      final vSink = File(videoTmp).openWrite();
      final vStream = _yt.videos.streamsClient.get(videoStream);
      await for (final chunk in vStream) {
        vSink.add(chunk);
        cumulativeDownloaded += chunk.length;
        updateProgress(
          cumulativeDownloaded,
          totalCombinedBytes,
          customStatus: 'Đang tải luồng Video (${format.displayQuality})',
        );
      }
      await vSink.flush();
      await vSink.close();

      // 2. Tải luồng Audio với timeout và fallback
      task.statusMessage = 'Đang tải luồng Âm thanh gốc...';
      _notify();

      bool audioSuccess = false;
      final aSink = File(audioTmp).openWrite();
      try {
        final aStream = _yt.videos.streamsClient.get(audioStream);
        await for (final chunk in aStream.timeout(const Duration(seconds: 8))) {
          aSink.add(chunk);
          cumulativeDownloaded += chunk.length;
          updateProgress(
            cumulativeDownloaded,
            totalCombinedBytes,
            customStatus: 'Đang tải luồng Âm thanh gốc',
          );
        }
        await aSink.flush();
        await aSink.close();
        audioSuccess = true;
      } catch (e) {
        debugPrint('Tải audio riêng lẻ timeout: $e. Sử dụng Muxed Stream dự phòng...');
        try {
          await aSink.flush();
          await aSink.close();
        } catch (_) {}
      }

      // Nếu audio-only bị throttle hoặc lỗi, lấy audio từ luồng Muxed tag 18 (siêu ổn định)
      if (!audioSuccess) {
        final muxedStream = manifest.muxed.firstWhereOrNull((m) => m.tag == 18) ??
            manifest.muxed.firstOrNull;
        if (muxedStream != null) {
          final muxTmp = _storage.generateTempPath(prefix: 'mux_v_${task.id}', extension: 'mp4');
          task.tempFiles.add(muxTmp);
          final mSink = File(muxTmp).openWrite();
          final mStream = _yt.videos.streamsClient.get(muxedStream);
          await for (final chunk in mStream) {
            mSink.add(chunk);
          }
          await mSink.flush();
          await mSink.close();
          await _processor.extractAudioCopy(videoPath: muxTmp, outputPath: audioTmp);
          await _storage.deleteFile(muxTmp);
          audioSuccess = true;
        }
      }

      // 3. Ghép luồng không nén lại (Remux Copy)
      task.status = DownloadStatus.merging;
      task.statusMessage = 'Đang ghép luồng (Không nén lại)...';
      _notify();

      final finalVideoPath = _storage.generateVideoPath(extension: 'mp4');
      await _processor.mergeVideoAndAudio(
        videoPath: videoTmp,
        audioPath: audioTmp,
        outputPath: finalVideoPath,
      );

      // Xóa tệp tạm
      await _storage.deleteFile(videoTmp);
      await _storage.deleteFile(audioTmp);

      return finalVideoPath;
    } else if (format.formatType == FormatType.audio) {
      // Tải Audio YouTube: Ưu tiên số 1 là Muxed stream (tag 18) vì tải cực nhanh (~1s), không bao giờ bị YouTube rate-limit
      final muxedStream = validManifest.muxed.firstWhereOrNull((m) => m.tag == 18) ??
          validManifest.muxed.firstOrNull;

      final itagStr = format.formatId.replaceAll('yt_audio_', '');
      final itag = int.tryParse(itagStr);

      yt.AudioStreamInfo? audioStream;
      if (itag != null) {
        audioStream = validManifest.audioOnly.firstWhereOrNull((s) => s.tag == itag);
      }
      audioStream ??= validManifest.audioOnly.firstWhereOrNull(
        (s) => s.container.name.toLowerCase() == 'mp4',
      ) ?? validManifest.audioOnly.withHighestBitrate();

      final ext = task.convertToMp3
          ? 'mp3'
          : ((audioStream.container.name.toLowerCase() == 'mp4' || muxedStream != null) ? 'm4a' : audioStream.container.name);
      final finalAudioPath = _storage.generateAudioPath(extension: ext);

      // 1. Tải tức thì qua luồng Muxed siêu tốc nếu có
      if (muxedStream != null) {
        task.statusMessage = 'Đang tải âm thanh (Tốc độ cao)...';
        _notify();

        final muxedTmp = _storage.generateTempPath(prefix: 'mux_${task.id}', extension: 'mp4');
        task.tempFiles.add(muxedTmp);
        final mSink = File(muxedTmp).openWrite();

        try {
          final mStream = _yt.videos.streamsClient.get(muxedStream);
          int mDownloaded = 0;
          final mTotal = muxedStream.size.totalBytes;
          await for (final chunk in mStream) {
            mSink.add(chunk);
            mDownloaded += chunk.length;
            updateProgress(mDownloaded, mTotal, customStatus: 'Đang tải âm thanh');
          }
          await mSink.flush();
          await mSink.close();

          task.status = DownloadStatus.processing;
          task.statusMessage = 'Đang trích xuất bản âm thanh chất lượng cao...';
          _notify();

          if (task.convertToMp3) {
            await _processor.convertToMp3(
              inputPath: muxedTmp,
              outputPath: finalAudioPath,
              bitrateKbps: task.mp3Bitrate ?? 320,
            );
          } else {
            await _processor.extractAudioCopy(
              videoPath: muxedTmp,
              outputPath: finalAudioPath,
            );
          }
          await _storage.deleteFile(muxedTmp);
          return finalAudioPath;
        } catch (e) {
          debugPrint('Tải qua Muxed thất bại: $e. Thử audio-only trực tiếp...');
        } finally {
          try {
            await mSink.flush();
            await mSink.close();
          } catch (_) {}
        }
      }

      // 2. Dự phòng: Tải qua luồng audio-only nếu không có muxed
      task.statusMessage = 'Đang tải âm thanh gốc...';
      _notify();

      final rawTmp = _storage.generateTempPath(
        prefix: 'raw_${task.id}',
        extension: audioStream.container.name.toLowerCase() == 'mp4' ? 'm4a' : audioStream.container.name,
      );
      task.tempFiles.add(rawTmp);
      final sink = File(rawTmp).openWrite();

      try {
        final stream = _yt.videos.streamsClient.get(audioStream);
        int downloaded = 0;
        final totalBytes = audioStream.size.totalBytes;

        final timedStream = stream.timeout(const Duration(seconds: 8));
        await for (final chunk in timedStream) {
          sink.add(chunk);
          downloaded += chunk.length;
          updateProgress(downloaded, totalBytes, customStatus: 'Đang tải âm thanh');
        }
        await sink.flush();
        await sink.close();

        if (task.convertToMp3) {
          task.status = DownloadStatus.converting;
          task.statusMessage = 'Đang chuyển đổi sang MP3 ${task.mp3Bitrate ?? 320}kbps...';
          _notify();
          await _processor.convertToMp3(
            inputPath: rawTmp,
            outputPath: finalAudioPath,
            bitrateKbps: task.mp3Bitrate ?? 320,
          );
          await _storage.deleteFile(rawTmp);
        } else {
          await File(rawTmp).rename(finalAudioPath);
        }
        return finalAudioPath;
      } finally {
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {}
      }
    } else {
      // Muxed video stream
      final itagStr = format.formatId.replaceAll('yt_', '');
      final itag = int.tryParse(itagStr);
      final stream = validManifest.muxed.firstWhere(
        (s) => s.tag == itag,
        orElse: () => validManifest.muxed.first,
      );

      final finalVideoPath = _storage.generateVideoPath(extension: stream.container.name);
      final sink = File(finalVideoPath).openWrite();
      try {
        final streamBytes = _yt.videos.streamsClient.get(stream);
        int downloaded = 0;
        await for (final chunk in streamBytes) {
          sink.add(chunk);
          downloaded += chunk.length;
          updateProgress(downloaded, stream.size.totalBytes, customStatus: 'Đang tải video');
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      return finalVideoPath;
    }
  }

  /// Tải cho TikTok, Facebook, Instagram, Twitter, Vimeo, Direct
  Future<String> _downloadGenericPlatform(
    DownloadTask task,
    void Function(int current, int total, {String? customStatus}) updateProgress,
  ) async {
    final info = task.mediaInfo;
    final format = task.selectedFormat;

    final isAudio = format.formatType == FormatType.audio;
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': '*/*',
    };

    if (info.platform == 'tiktok') {
      headers['Referer'] = 'https://www.tiktok.com/';
      headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    } else if (info.platform == 'instagram') {
      headers['Referer'] = 'https://www.instagram.com/';
    } else if (info.platform == 'facebook') {
      headers['Referer'] = 'https://www.facebook.com/';
    }

    Uri streamUri = format.streamUrl;
    final urlStr = streamUri.toString();
    if (urlStr.contains(r'\u002') ||
        urlStr.contains(r'\/') ||
        (urlStr.contains('//') && !urlStr.startsWith('http://') && !urlStr.startsWith('https://'))) {
      final cleaned = _cleanUrl(urlStr);
      final parsed = Uri.tryParse(cleaned);
      if (parsed != null && parsed.hasAuthority) {
        streamUri = parsed;
      }
    }

    final request = http.Request('GET', streamUri);
    request.headers.addAll(headers);

    http.StreamedResponse streamedResponse = await _httpClient.send(request);

    // Tự động phục hồi khi gặp mã lỗi 403 Forbidden
    if (streamedResponse.statusCode == 403) {
      debugPrint('Luồng bị 403 Forbidden. Đang kích hoạt cơ chế phục hồi tự động...');
      // 1. Thử gửi lại không kèm Referer (nhiều CDN chặn Referer từ bên ngoài)
      final retryReq = http.Request('GET', streamUri);
      retryReq.headers.addAll({
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': '*/*',
      });
      final retryResp = await _httpClient.send(retryReq);
      if (retryResp.statusCode < 400) {
        streamedResponse = retryResp;
      } else if (info.platform == 'tiktok') {
        // 2. Nếu là TikTok, tự động lấy luồng CDN mới nhất qua TikWM
        task.statusMessage = 'Đang làm mới luồng TikTok...';
        _notify();
        final freshUrl = await _getFreshTikTokUrl(info.sourceUrl, isAudio);
        if (freshUrl != null) {
          final freshUri = Uri.parse(freshUrl);
          final freshReq = http.Request('GET', freshUri);
          freshReq.headers['User-Agent'] =
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
          final freshResp = await _httpClient.send(freshReq);
          if (freshResp.statusCode < 400) {
            streamedResponse = freshResp;
          }
        }
      }
    }

    if (streamedResponse.statusCode >= 400) {
      throw HttpException('Máy chủ phản hồi mã lỗi ${streamedResponse.statusCode}');
    }

    final totalBytes = streamedResponse.contentLength ?? (format.estimatedSizeBytes ?? 0);

    if (isAudio) {
      // Nguồn mạng xã hội là video, tải tạm về rồi trích xuất audio chuẩn
      final tempVideo = _storage.generateTempPath(prefix: 'raw_media_${task.id}', extension: 'mp4');
      task.tempFiles.add(tempVideo);

      final file = File(tempVideo);
      final sink = file.openWrite();
      try {
        int downloaded = 0;
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          updateProgress(downloaded, totalBytes, customStatus: 'Đang tải luồng nguồn');
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      task.status = DownloadStatus.processing;
      task.statusMessage = 'Đang trích xuất âm thanh...';
      _notify();

      if (task.convertToMp3) {
        final finalAudioPath = _storage.generateAudioPath(extension: 'mp3');
        await _processor.convertToMp3(
          inputPath: tempVideo,
          outputPath: finalAudioPath,
          bitrateKbps: task.mp3Bitrate ?? 320,
        );
        await _storage.deleteFile(tempVideo);
        return finalAudioPath;
      } else {
        final finalAudioPath = _storage.generateAudioPath(extension: 'm4a');
        await _processor.extractAudioCopy(
          videoPath: tempVideo,
          outputPath: finalAudioPath,
        );
        await _storage.deleteFile(tempVideo);
        return finalAudioPath;
      }
    } else {
      final extension = format.container.isNotEmpty ? format.container : 'mp4';
      final finalPath = _storage.generateVideoPath(extension: extension);
      final file = File(finalPath);
      final sink = file.openWrite();
      try {
        int downloaded = 0;
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          updateProgress(downloaded, totalBytes, customStatus: 'Đang tải video');
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      return finalPath;
    }
  }

  void cancelTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      task.status = DownloadStatus.canceled;
      task.statusMessage = 'Đã hủy tải';
      _notify();
    }
  }

  void retryTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final oldTask = _tasks[index];
      oldTask.status = DownloadStatus.queued;
      oldTask.statusMessage = 'Chờ trong hàng đợi';
      oldTask.progress = 0.0;
      oldTask.downloadedBytes = 0;
      oldTask.errorMessage = null;
      _notify();
      _processQueue();
    }
  }

  Future<void> deleteTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      for (final tmp in task.tempFiles) {
        await _storage.deleteFile(tmp);
      }
      _tasks.removeAt(index);
      _notify();
    }
  }

  String _cleanUrl(String raw) {
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

  Future<String?> _getFreshTikTokUrl(Uri sourceUrl, bool isAudio) async {
    try {
      final tikwmUri =
          Uri.parse('https://www.tikwm.com/api/?url=${Uri.encodeComponent(sourceUrl.toString())}');
      final res = await _httpClient.get(
        tikwmUri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['code'] == 0 && data['data'] != null) {
          final item = data['data'] as Map<String, dynamic>;
          if (isAudio && item['music'] != null) {
            return item['music'] as String;
          }
          return (item['play'] ?? item['wmplay']) as String?;
        }
      }
    } catch (_) {}
    return null;
  }
}
