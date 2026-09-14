import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class MediaProcessingException implements Exception {
  final String message;
  final String? logs;
  const MediaProcessingException(this.message, [this.logs]);

  @override
  String toString() => '$message ${logs != null ? "\nChi tiết: $logs" : ""}';
}

class MediaProcessor {
  static final MediaProcessor _instance = MediaProcessor._internal();
  factory MediaProcessor() => _instance;
  MediaProcessor._internal();

  /// Ghép 2 luồng video và audio riêng lẻ vào tệp MP4
  /// Giữ nguyên luồng video (-c:v copy), encode audio sang AAC tiêu chuẩn để đảm bảo tương thích mọi player.
  Future<void> mergeVideoAndAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    final cmd = '-y -i "$videoPath" -i "$audioPath" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest "$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      // Thử phương án dự phòng dùng copy toàn bộ nếu container tương thích
      final fallbackCmd = '-y -i "$videoPath" -i "$audioPath" -c copy -map 0:v:0 -map 1:a:0 -shortest "$outputPath"';
      final fallbackSession = await FFmpegKit.execute(fallbackCmd);
      final fallbackCode = await fallbackSession.getReturnCode();

      if (!ReturnCode.isSuccess(fallbackCode)) {
        final logs = await session.getAllLogsAsString();
        throw MediaProcessingException('Không thể ghép luồng video và âm thanh', logs);
      }
    }

    final outputFile = File(outputPath);
    if (!await outputFile.exists() || await outputFile.length() == 0) {
      throw const MediaProcessingException('Tệp video sau khi xử lý bị lỗi hoặc rỗng');
    }
  }

  /// Chuyển đổi âm thanh sang MP3 với bitrate lựa chọn (128k, 192k, 256k, 320k)
  Future<void> convertToMp3({
    required String inputPath,
    required String outputPath,
    int bitrateKbps = 320,
  }) async {
    // Thử với libmp3lame trước
    final cmd = '-y -i "$inputPath" -vn -c:a libmp3lame -b:a ${bitrateKbps}k "$outputPath"';
    try {
      final session = await FFmpegKit.execute(cmd).timeout(const Duration(seconds: 20));
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        // Fallback 1: dùng encoder mp3 mặc định
        final fallbackCmd = '-y -i "$inputPath" -vn -c:a mp3 -b:a ${bitrateKbps}k "$outputPath"';
        final fbSession = await FFmpegKit.execute(fallbackCmd).timeout(const Duration(seconds: 20));
        final fbCode = await fbSession.getReturnCode();

        if (!ReturnCode.isSuccess(fbCode)) {
          // Fallback 2: nếu vẫn lỗi thì copy sang container đích hoặc encode AAC
          final aacCmd = '-y -i "$inputPath" -vn -c:a aac -b:a 192k "$outputPath"';
          final aacSession = await FFmpegKit.execute(aacCmd).timeout(const Duration(seconds: 20));
          final aacCode = await aacSession.getReturnCode();

          if (!ReturnCode.isSuccess(aacCode)) {
            final logs = await session.getAllLogsAsString();
            throw MediaProcessingException('Lỗi chuyển đổi âm thanh', logs);
          }
        }
      }
    } catch (e) {
      if (e is MediaProcessingException) rethrow;
      throw MediaProcessingException('Quá trình xử lý âm thanh bị quá hạn: $e');
    }

    final out = File(outputPath);
    if (!await out.exists() || await out.length() == 0) {
      throw const MediaProcessingException('Tệp âm thanh sau chuyển đổi không hợp lệ');
    }
  }

  /// Trích xuất luồng âm thanh từ video
  Future<void> extractAudioCopy({
    required String videoPath,
    required String outputPath,
  }) async {
    final cmd = '-y -i "$videoPath" -vn -c:a copy "$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final fallbackCmd = '-y -i "$videoPath" -vn -c:a aac -b:a 192k "$outputPath"';
      final fallbackSession = await FFmpegKit.execute(fallbackCmd);
      final fallbackCode = await fallbackSession.getReturnCode();
      if (!ReturnCode.isSuccess(fallbackCode)) {
        final logs = await fallbackSession.getAllLogsAsString();
        throw MediaProcessingException('Không thể trích xuất âm thanh từ video', logs);
      }
    }
  }
}
