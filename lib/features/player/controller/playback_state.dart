import '../../../core/database/models/media_item_model.dart';
import '../../resolver/domain/media_info.dart';
import '../../resolver/domain/media_format.dart';

enum PlaybackRepeatMode { off, all, one }

class PlaybackStateModel {
  final MediaItemModel? localItem;
  final MediaInfo? onlineInfo;
  final MediaFormat? onlineFormat;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final double speed;
  final bool isShuffle;
  final PlaybackRepeatMode repeatMode;
  final List<MediaItemModel> queue;
  final int queueIndex;
  final bool isVideoMode;
  final bool isAudioOnly; // Video Audio-Only mode
  final bool isPipActive;
  final bool is2xSpeedActive;

  const PlaybackStateModel({
    this.localItem,
    this.onlineInfo,
    this.onlineFormat,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.speed = 1.0,
    this.isShuffle = false,
    this.repeatMode = PlaybackRepeatMode.off,
    this.queue = const [],
    this.queueIndex = 0,
    this.isVideoMode = false,
    this.isAudioOnly = false,
    this.isPipActive = false,
    this.is2xSpeedActive = false,
  });

  bool get hasMedia => localItem != null || onlineInfo != null;

  String? get mediaId => localItem?.id;
  int get currentIndex => queueIndex;
  String get title => localItem?.title ?? onlineInfo?.title ?? '';
  String get artist => localItem?.artist ?? onlineInfo?.author ?? '';
  String? get thumbnailPath => localItem?.thumbnailPath;
  String? get thumbnailUrl => localItem?.thumbnailUrl ?? onlineInfo?.thumbnailUrl;

  PlaybackStateModel copyWith({
    MediaItemModel? localItem,
    bool clearLocalItem = false,
    MediaInfo? onlineInfo,
    bool clearOnlineInfo = false,
    MediaFormat? onlineFormat,
    bool clearOnlineFormat = false,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    double? speed,
    bool? isShuffle,
    PlaybackRepeatMode? repeatMode,
    List<MediaItemModel>? queue,
    int? queueIndex,
    bool? isVideoMode,
    bool? isAudioOnly,
    bool? isPipActive,
    bool? is2xSpeedActive,
  }) {
    return PlaybackStateModel(
      localItem: clearLocalItem ? null : (localItem ?? this.localItem),
      onlineInfo: clearOnlineInfo ? null : (onlineInfo ?? this.onlineInfo),
      onlineFormat: clearOnlineFormat ? null : (onlineFormat ?? this.onlineFormat),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      speed: speed ?? this.speed,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      isVideoMode: isVideoMode ?? this.isVideoMode,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
      isPipActive: isPipActive ?? this.isPipActive,
      is2xSpeedActive: is2xSpeedActive ?? this.is2xSpeedActive,
    );
  }
}
