import 'package:dio/dio.dart';
import '../../resolver/domain/media_format.dart';
import '../../resolver/domain/media_info.dart';
import 'download_status.dart';

class DownloadTask {
  final String id;
  final MediaInfo mediaInfo;
  final MediaFormat selectedFormat;
  final bool convertToMp3;
  final int? mp3Bitrate; // 128, 192, 256, 320 kbps

  DownloadStatus status;
  int downloadedBytes;
  int totalBytes;
  double progress; // 0.0 to 1.0
  int speedBytesPerSec;
  int etaSeconds;
  String statusMessage;
  String? errorMessage;
  String? finalLocalPath;
  List<String> tempFiles;
  CancelToken? cancelToken;

  DownloadTask({
    required this.id,
    required this.mediaInfo,
    required this.selectedFormat,
    this.convertToMp3 = false,
    this.mp3Bitrate,
    this.status = DownloadStatus.queued,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    this.speedBytesPerSec = 0,
    this.etaSeconds = 0,
    this.statusMessage = 'Chờ tải',
    this.errorMessage,
    this.finalLocalPath,
    List<String>? tempFiles,
    this.cancelToken,
  }) : tempFiles = tempFiles ?? [];

  bool get isVideo => selectedFormat.hasVideo;
  bool get isAudio => selectedFormat.formatType == FormatType.audio;

  String get formattedProgress => '${(progress * 100).toStringAsFixed(1)}%';

  String get formattedSpeed {
    if (speedBytesPerSec <= 0) return '0 KB/s';
    if (speedBytesPerSec < 1024 * 1024) {
      return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedDownloadedSize => _formatBytes(downloadedBytes);
  String get formattedTotalSize => totalBytes > 0 ? _formatBytes(totalBytes) : 'Đang tính...';

  String get formattedEta {
    if (etaSeconds <= 0) return '--:--';
    final m = etaSeconds ~/ 60;
    final s = etaSeconds % 60;
    if (m > 0) return '${m}p ${s}s';
    return '${s}s';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
