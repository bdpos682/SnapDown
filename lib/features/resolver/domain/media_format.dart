enum FormatType {
  video,
  audio,
  muxed, // Contains both video and audio in single stream
}

class MediaFormat {
  final String formatId;
  final FormatType formatType;
  final String container; // 'mp4', 'm4a', 'webm', 'mp3', 'opus'
  final String? resolution; // '4K', '1080p', '720p', etc.
  final int? width;
  final int? height;
  final int? fps;
  final String? videoCodec;
  final String? audioCodec;
  final int? bitrate; // in bits per second
  final int? sampleRate; // in Hz
  final int? channels;
  final int? estimatedSizeBytes;
  final bool hasVideo;
  final bool hasAudio;
  final Uri streamUrl;
  final Uri? audioStreamUrl; // for separate adaptive video-only + audio-only streams
  final bool isBestAudio;
  final DateTime? expiry;

  const MediaFormat({
    required this.formatId,
    required this.formatType,
    required this.container,
    this.resolution,
    this.width,
    this.height,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.bitrate,
    this.sampleRate,
    this.channels,
    this.estimatedSizeBytes,
    required this.hasVideo,
    required this.hasAudio,
    required this.streamUrl,
    this.audioStreamUrl,
    this.isBestAudio = false,
    this.expiry,
  });

  bool get isAdaptive => hasVideo && !hasAudio && audioStreamUrl != null;

  String get formattedBitrate {
    if (bitrate == null) return '';
    final kbps = (bitrate! / 1000).round();
    return '$kbps kbps';
  }

  String get formattedSize {
    if (estimatedSizeBytes == null || estimatedSizeBytes! <= 0) return 'Variable';
    final bytes = estimatedSizeBytes!;
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get displayQuality {
    if (formatType == FormatType.audio) {
      if (isBestAudio) return 'Best Audio';
      return formattedBitrate.isNotEmpty ? formattedBitrate : container.toUpperCase();
    }
    return resolution ?? (height != null ? '${height}p' : 'Default');
  }

  String get displayDetails {
    final parts = <String>[];
    parts.add(container.toUpperCase());
    if (videoCodec != null && videoCodec!.isNotEmpty) parts.add(videoCodec!);
    if (fps != null && fps! > 30) parts.add('${fps}fps');
    if (audioCodec != null && audioCodec!.isNotEmpty) parts.add(audioCodec!);
    if (bitrate != null && formatType == FormatType.audio) parts.add(formattedBitrate);
    parts.add(formattedSize);
    return parts.join(' • ');
  }
}
