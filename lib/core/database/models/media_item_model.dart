import '../../utils/html_utils.dart';

class MediaItemModel {
  final String id;
  final String sourceUrl;
  final String sourcePlatform;
  final String remoteId;
  final String title;
  final String artist;
  final String? description;
  final String mediaType; // 'audio' | 'video'
  final String localPath;
  final String? thumbnailPath;
  final String? thumbnailUrl;
  final int durationMs;
  final String? audioCodec;
  final String? videoCodec;
  final String container;
  final int? bitrate;
  final int? width;
  final int? height;
  final int? fps;
  final int fileSize;
  final DateTime downloadedAt;
  final DateTime? lastPlayedAt;
  final bool isFavorite;
  final int playCount;
  final int lastPositionMs;
  final bool isCompleted;

  const MediaItemModel({
    required this.id,
    required this.sourceUrl,
    required this.sourcePlatform,
    required this.remoteId,
    required this.title,
    required this.artist,
    this.description,
    required this.mediaType,
    required this.localPath,
    this.thumbnailPath,
    this.thumbnailUrl,
    required this.durationMs,
    this.audioCodec,
    this.videoCodec,
    required this.container,
    this.bitrate,
    this.width,
    this.height,
    this.fps,
    required this.fileSize,
    required this.downloadedAt,
    this.lastPlayedAt,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPositionMs = 0,
    this.isCompleted = false,
  });

  bool get isVideo => mediaType == 'video';
  bool get isAudio => mediaType == 'audio';

  String get formattedDuration {
    final duration = Duration(milliseconds: durationMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedResolution {
    if (width != null && height != null) {
      if (height! >= 2160) return '4K';
      if (height! >= 1440) return '1440p';
      if (height! >= 1080) return '1080p';
      if (height! >= 720) return '720p';
      if (height! >= 480) return '480p';
      return '${height}p';
    }
    return '';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_url': sourceUrl,
      'source_platform': sourcePlatform,
      'remote_id': remoteId,
      'title': title,
      'artist': artist,
      'description': description,
      'media_type': mediaType,
      'local_path': localPath,
      'thumbnail_path': thumbnailPath,
      'thumbnail_url': thumbnailUrl,
      'duration_ms': durationMs,
      'audio_codec': audioCodec,
      'video_codec': videoCodec,
      'container': container,
      'bitrate': bitrate,
      'width': width,
      'height': height,
      'fps': fps,
      'file_size': fileSize,
      'downloaded_at': downloadedAt.toIso8601String(),
      'last_played_at': lastPlayedAt?.toIso8601String(),
      'is_favorite': isFavorite ? 1 : 0,
      'play_count': playCount,
      'last_position_ms': lastPositionMs,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory MediaItemModel.fromMap(Map<String, dynamic> map) {
    return MediaItemModel(
      id: map['id'] as String,
      sourceUrl: map['source_url'] as String,
      sourcePlatform: map['source_platform'] as String,
      remoteId: map['remote_id'] as String,
      title: HtmlUtils.unescape(map['title'] as String),
      artist: HtmlUtils.unescape(map['artist'] as String),
      description: map['description'] as String?,
      mediaType: map['media_type'] as String,
      localPath: map['local_path'] as String,
      thumbnailPath: map['thumbnail_path'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      durationMs: map['duration_ms'] as int? ?? 0,
      audioCodec: map['audio_codec'] as String?,
      videoCodec: map['video_codec'] as String?,
      container: map['container'] as String? ?? 'mp4',
      bitrate: map['bitrate'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      fps: map['fps'] as int?,
      fileSize: map['file_size'] as int? ?? 0,
      downloadedAt: DateTime.tryParse(map['downloaded_at'] as String? ?? '') ?? DateTime.now(),
      lastPlayedAt: map['last_played_at'] != null ? DateTime.tryParse(map['last_played_at'] as String) : null,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      playCount: map['play_count'] as int? ?? 0,
      lastPositionMs: map['last_position_ms'] as int? ?? 0,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
    );
  }

  MediaItemModel copyWith({
    String? id,
    String? sourceUrl,
    String? sourcePlatform,
    String? remoteId,
    String? title,
    String? artist,
    String? description,
    String? mediaType,
    String? localPath,
    String? thumbnailPath,
    String? thumbnailUrl,
    int? durationMs,
    String? audioCodec,
    String? videoCodec,
    String? container,
    int? bitrate,
    int? width,
    int? height,
    int? fps,
    int? fileSize,
    DateTime? downloadedAt,
    DateTime? lastPlayedAt,
    bool? isFavorite,
    int? playCount,
    int? lastPositionMs,
    bool? isCompleted,
  }) {
    return MediaItemModel(
      id: id ?? this.id,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      description: description ?? this.description,
      mediaType: mediaType ?? this.mediaType,
      localPath: localPath ?? this.localPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      audioCodec: audioCodec ?? this.audioCodec,
      videoCodec: videoCodec ?? this.videoCodec,
      container: container ?? this.container,
      bitrate: bitrate ?? this.bitrate,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      fileSize: fileSize ?? this.fileSize,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
