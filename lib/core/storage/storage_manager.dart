import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class StorageBreakdown {
  final int audioBytes;
  final int videoBytes;
  final int artworkBytes;
  final int tempBytes;
  final int totalBytes;

  const StorageBreakdown({
    required this.audioBytes,
    required this.videoBytes,
    required this.artworkBytes,
    required this.tempBytes,
    required this.totalBytes,
  });

  String get formattedTotal => _formatBytes(totalBytes);
  String get formattedAudio => _formatBytes(audioBytes);
  String get formattedVideo => _formatBytes(videoBytes);
  String get formattedArtwork => _formatBytes(artworkBytes);
  String get formattedTemp => _formatBytes(tempBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class StorageManager {
  static final StorageManager _instance = StorageManager._internal();
  factory StorageManager() => _instance;
  StorageManager._internal();

  late final Directory _baseDir;
  late final Directory _audioDir;
  late final Directory _videoDir;
  late final Directory _artworkDir;
  late final Directory _tempDir;
  bool _initialized = false;

  final _uuid = const Uuid();

  Future<void> init() async {
    if (_initialized) return;

    final appDocDir = await getApplicationDocumentsDirectory();
    _baseDir = Directory(p.join(appDocDir.path, 'SnapDown'));

    _audioDir = Directory(p.join(_baseDir.path, 'media', 'audio'));
    _videoDir = Directory(p.join(_baseDir.path, 'media', 'video'));
    _artworkDir = Directory(p.join(_baseDir.path, 'media', 'artwork'));
    _tempDir = Directory(p.join(_baseDir.path, 'media', 'temp'));

    await Future.wait([
      _audioDir.create(recursive: true),
      _videoDir.create(recursive: true),
      _artworkDir.create(recursive: true),
      _tempDir.create(recursive: true),
    ]);

    _initialized = true;
  }

  Directory get audioDir => _audioDir;
  Directory get videoDir => _videoDir;
  Directory get artworkDir => _artworkDir;
  Directory get tempDir => _tempDir;

  String generateAudioPath({required String extension}) {
    final cleanExt = extension.startsWith('.') ? extension.substring(1) : extension;
    return p.join(_audioDir.path, '${_uuid.v4()}.$cleanExt');
  }

  String generateVideoPath({required String extension}) {
    final cleanExt = extension.startsWith('.') ? extension.substring(1) : extension;
    return p.join(_videoDir.path, '${_uuid.v4()}.$cleanExt');
  }

  String generateArtworkPath({required String extension}) {
    final cleanExt = extension.startsWith('.') ? extension.substring(1) : extension;
    return p.join(_artworkDir.path, '${_uuid.v4()}.$cleanExt');
  }

  String generateTempPath({required String prefix, required String extension}) {
    final cleanExt = extension.startsWith('.') ? extension.substring(1) : extension;
    return p.join(_tempDir.path, '${prefix}_${_uuid.v4()}.$cleanExt');
  }

  Future<void> clearTempFiles() async {
    if (!_initialized) await init();
    try {
      if (await _tempDir.exists()) {
        final files = _tempDir.listSync();
        for (final file in files) {
          if (file is File) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<StorageBreakdown> getStorageBreakdown() async {
    if (!_initialized) await init();

    final audioSize = await _calculateDirSize(_audioDir);
    final videoSize = await _calculateDirSize(_videoDir);
    final artworkSize = await _calculateDirSize(_artworkDir);
    final tempSize = await _calculateDirSize(_tempDir);

    return StorageBreakdown(
      audioBytes: audioSize,
      videoBytes: videoSize,
      artworkBytes: artworkSize,
      tempBytes: tempSize,
      totalBytes: audioSize + videoSize + artworkSize + tempSize,
    );
  }

  Future<int> _calculateDirSize(Directory dir) async {
    try {
      if (!await dir.exists()) return 0;
      int total = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
