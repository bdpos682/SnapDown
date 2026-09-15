import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/widgets.dart';
import '../../../core/database/models/media_item_model.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../resolver/domain/media_format.dart';
import '../../resolver/domain/media_info.dart';
import '../../../main.dart';
import '../service/snap_audio_handler.dart';
import 'playback_state.dart';

final playbackControllerProvider =
    NotifierProvider<GlobalPlaybackController, PlaybackStateModel>(
  GlobalPlaybackController.new,
);

class GlobalPlaybackController extends Notifier<PlaybackStateModel> with WidgetsBindingObserver {
  static const MethodChannel _pipChannel = MethodChannel('com.snapvideo.snapdown/pip');
  VideoPlayerController? _videoController;

  late final MediaRepository _repository;
  SnapAudioHandler? _audioHandler;

  Timer? _positionSaveTimer;
  StreamSubscription? _audioStateSub;
  StreamSubscription? _audioPosSub;

  Duration _lastEmittedAudioPos = Duration.zero;
  Duration _lastEmittedVideoPos = Duration.zero;

  bool _isBackgroundAudioActive = false;
  double _savedSpeedBefore2x = 1.0;

  VideoPlayerController? get videoController => _videoController;
  bool get isBackgroundAudioActive => _isBackgroundAudioActive;

  /// Cập nhật state an toàn, đảm bảo không gọi notifyListeners khi Flutter đang trong pha persistentCallbacks
  /// tránh hoàn toàn lỗi '_lifecycleState != _ElementLifecycle.defunct'.
  void _safeSetState(PlaybackStateModel Function(PlaybackStateModel) updater) {
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state = updater(state);
      });
    } else {
      state = updater(state);
    }
  }

  @override
  PlaybackStateModel build() {
    _repository = MediaRepository();
    _initAudioHandler();

    WidgetsBinding.instance.addObserver(this);

    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final isInPip = call.arguments as bool? ?? false;
        state = state.copyWith(isPipActive: isInPip);
      }
    });

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _pipChannel.setMethodCallHandler(null);
      _positionSaveTimer?.cancel();
      _audioStateSub?.cancel();
      _audioPosSub?.cancel();
      _videoController?.dispose();
      _videoController = null;
      _audioHandler?.stop();
    });

    return const PlaybackStateModel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (this.state.isVideoMode) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        // App chuyển sang nền hoặc tắt màn hình điện thoại
        if (this.state.isPlaying && !this.state.isPipActive && !_isBackgroundAudioActive) {
          _handoffVideoToBackgroundAudio();
        }
      } else if (state == AppLifecycleState.resumed) {
        // App quay trở lại màn hình chính
        if (_isBackgroundAudioActive && !this.state.isAudioOnly) {
          _handoffBackgroundAudioToVideo();
        }
      }
    }
  }

  Future<void> _handoffVideoToBackgroundAudio() async {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final currentPos = _videoController!.value.position;
    final wasPlaying = _videoController!.value.isPlaying;
    if (!wasPlaying) return;

    await _videoController!.pause();
    _isBackgroundAudioActive = true;

    final item = state.localItem;
    final online = state.onlineInfo;
    final onlineFmt = state.onlineFormat;

    if (item != null) {
      await _audioHandler?.setMediaSource(
        uri: item.localPath,
        title: item.title,
        artist: item.artist,
        artworkUri: item.thumbnailPath,
        duration: state.duration,
        isLocal: true,
      );
    } else if (online != null && onlineFmt != null) {
      await _audioHandler?.setMediaSource(
        uri: onlineFmt.streamUrl.toString(),
        title: online.title,
        artist: online.author,
        artworkUri: online.thumbnailUrl,
        duration: state.duration,
        isLocal: false,
      );
    }

    await _audioHandler?.seek(currentPos);
    await _audioHandler?.setSpeed(state.speed);
    await _audioHandler?.play();
  }

  Future<void> _handoffBackgroundAudioToVideo() async {
    if (_audioHandler == null) return;
    final audioPos = _audioHandler!.player.position;
    final isPlaying = _audioHandler!.player.playing;

    await _audioHandler!.pause();
    _isBackgroundAudioActive = false;

    if (_videoController != null && _videoController!.value.isInitialized) {
      await _videoController!.seekTo(audioPos);
      if (isPlaying) {
        await _videoController!.play();
      }
    }
  }

  Future<void> _initAudioHandler() async {
    try {
      _audioHandler = globalAudioHandler;
    } catch (_) {
      _audioHandler = SnapAudioHandler();
    }

    _audioStateSub = _audioHandler!.playbackState.listen((ps) {
      if (!state.isVideoMode || _isBackgroundAudioActive || state.isAudioOnly) {
        _safeSetState((s) => s.copyWith(
          isPlaying: ps.playing,
          bufferedPosition: ps.bufferedPosition,
          speed: ps.speed,
        ));

        if (ps.processingState == AudioProcessingState.completed) {
          _handlePlaybackCompleted();
        }
      }
    });

    _audioPosSub = _audioHandler!.player.positionStream.listen((pos) {
      if (!state.isVideoMode || _isBackgroundAudioActive || state.isAudioOnly) {
        final diff = (pos - _lastEmittedAudioPos).abs();
        if (diff >= const Duration(milliseconds: 250) || pos == Duration.zero) {
          _lastEmittedAudioPos = pos;
          _safeSetState((s) => s.copyWith(position: pos));
        }
      }
    });

    _audioHandler!.player.durationStream.listen((dur) {
      if ((!state.isVideoMode || _isBackgroundAudioActive || state.isAudioOnly) && dur != null) {
        _safeSetState((s) => s.copyWith(duration: dur));
      }
    });

    _startPeriodicPositionSave();
  }

  void _startPeriodicPositionSave() {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveCurrentPosition();
    });
  }

  Future<void> _saveCurrentPosition() async {
    final item = state.localItem;
    if (item != null && state.position > Duration.zero) {
      final isCompleted = state.duration > Duration.zero &&
          state.position >= (state.duration - const Duration(seconds: 5));
      await _repository.updatePlaybackPosition(
        id: item.id,
        positionMs: state.position.inMilliseconds,
        isCompleted: isCompleted,
      );
    }
  }

  /// Plays a downloaded local media item (audio or video)
  /// By default, songs ALWAYS start at 0:00 (resumePosition: false)
  Future<void> playLocalItem(
    MediaItemModel item, {
    List<MediaItemModel>? queue,
    bool resumePosition = false,
  }) async {
    await _stopCurrent();

    final isVideo = item.isVideo;
    // Songs and videos in normal playlist flow always start at 0:00 unless resumePosition is explicitly true
    final initialPos = resumePosition ? Duration(milliseconds: item.lastPositionMs) : Duration.zero;

    final updatedQueue = queue ?? [item];
    final queueIndex = updatedQueue.indexWhere((m) => m.id == item.id).clamp(0, updatedQueue.length - 1);

    state = state.copyWith(
      localItem: item,
      clearOnlineInfo: true,
      clearOnlineFormat: true,
      isVideoMode: isVideo,
      queue: updatedQueue,
      queueIndex: queueIndex,
      isAudioOnly: false,
      position: initialPos,
    );

    await _repository.recordPlayStarted(item.id);

    if (isVideo) {
      _isBackgroundAudioActive = false;
      final file = File(item.localPath);
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();

      if (initialPos > Duration.zero && initialPos < _videoController!.value.duration) {
        await _videoController!.seekTo(initialPos);
      }

      state = state.copyWith(
        duration: _videoController!.value.duration,
        isPlaying: true,
      );

      _videoController!.addListener(_onVideoTick);
      await _videoController!.play();
      await updateAutoPip(true);
    } else {
      await _audioHandler?.setMediaSource(
        uri: item.localPath,
        title: item.title,
        artist: item.artist,
        artworkUri: item.thumbnailPath,
        duration: Duration(milliseconds: item.durationMs),
        isLocal: true,
      );

      if (initialPos > Duration.zero) {
        await _audioHandler?.seek(initialPos);
      }

      await _audioHandler?.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  /// Plays all tracks in a list starting from beginning (0:00) with queue set to all tracks
  Future<void> playAll(List<MediaItemModel> tracks, {bool shuffle = false}) async {
    if (tracks.isEmpty) return;
    state = state.copyWith(isShuffle: shuffle);
    final startTrack = shuffle && tracks.length > 1
        ? tracks[Random().nextInt(tracks.length)]
        : tracks.first;
    await playLocalItem(startTrack, queue: tracks, resumePosition: false);
  }

  /// Plays an online stream directly without downloading first
  Future<void> playOnlineStream(MediaInfo info, MediaFormat format) async {
    await _stopCurrent();

    final isVideo = format.hasVideo;

    state = state.copyWith(
      onlineInfo: info,
      onlineFormat: format,
      clearLocalItem: true,
      isVideoMode: isVideo,
      isAudioOnly: false,
      position: Duration.zero,
    );

    if (isVideo) {
      _isBackgroundAudioActive = false;
      _videoController = VideoPlayerController.networkUrl(format.streamUrl);
      await _videoController!.initialize();

      state = state.copyWith(
        duration: _videoController!.value.duration,
        isPlaying: true,
      );

      _videoController!.addListener(_onVideoTick);
      await _videoController!.play();
      await updateAutoPip(true);
    } else {
      await _audioHandler?.setMediaSource(
        uri: format.streamUrl.toString(),
        title: info.title,
        artist: info.author,
        artworkUri: info.thumbnailUrl,
        duration: info.duration,
        isLocal: false,
      );
      await _audioHandler?.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  bool _isHandlingCompletion = false;

  void _onVideoTick() {
    if (_videoController == null) return;
    final val = _videoController!.value;
    final diff = (val.position - _lastEmittedVideoPos).abs();
    final shouldUpdatePos = diff >= const Duration(milliseconds: 250) || val.position == Duration.zero;
    final statusChanged = val.isPlaying != state.isPlaying || val.duration != state.duration;

    if (shouldUpdatePos || statusChanged) {
      _lastEmittedVideoPos = val.position;
      _safeSetState((s) => s.copyWith(
        isPlaying: val.isPlaying,
        position: val.position,
        duration: val.duration,
        bufferedPosition: val.buffered.isNotEmpty ? val.buffered.last.end : Duration.zero,
      ));
    }

    if (val.duration > Duration.zero &&
        val.position >= (val.duration - const Duration(milliseconds: 200)) &&
        !val.isPlaying) {
      _handlePlaybackCompleted();
    }
  }

  Future<void> _handlePlaybackCompleted() async {
    if (_isHandlingCompletion) return;
    _isHandlingCompletion = true;

    try {
      if (state.localItem != null) {
        // Reset finished track position to 0 in database so it will never resume at the end
        await _repository.updatePlaybackPosition(
          id: state.localItem!.id,
          positionMs: 0,
          isCompleted: true,
        );
      }

      if (state.repeatMode == PlaybackRepeatMode.one) {
        await seek(Duration.zero);
        if (state.isVideoMode) {
          await _videoController?.play();
          state = state.copyWith(isPlaying: true);
        } else {
          await _audioHandler?.play();
          state = state.copyWith(isPlaying: true);
        }
      } else if (state.queue.isNotEmpty) {
        await next();
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 600), () {
        _isHandlingCompletion = false;
      });
    }
  }

  Future<void> pause() async {
    if (state.isVideoMode) {
      await _videoController?.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await _audioHandler?.pause();
    }
  }

  Future<void> stop() async {
    await _stopCurrent();
    state = const PlaybackStateModel();
  }

  Future<void> dismissPlayer() async {
    await _stopCurrent();
    state = const PlaybackStateModel();
  }

  Future<void> seekTo(Duration position) async => await seek(position);

  Future<void> seekForward(Duration delta) async => await seekRelative(delta);

  Future<void> seekBackward(Duration delta) async => await seekRelative(-delta);

  Future<void> skipToNext() async => await next();

  Future<void> skipToPrevious() async => await previous();

  void cycleRepeatMode() => toggleRepeat();

  Future<void> enterPipMode() async => await enterPip();

  Future<void> playQueueItem(int index) async {
    if (index >= 0 && index < state.queue.length) {
      await playLocalItem(state.queue[index], queue: state.queue, resumePosition: false);
    }
  }

  Future<void> togglePlayPause() async {
    if (state.isVideoMode && !_isBackgroundAudioActive && !state.isAudioOnly) {
      if (_videoController == null) return;
      if (_videoController!.value.isPlaying) {
        await _videoController!.pause();
        state = state.copyWith(isPlaying: false);
        await updateAutoPip(false);
      } else {
        await _videoController!.play();
        state = state.copyWith(isPlaying: true);
        await updateAutoPip(true);
      }
    } else {
      if (state.isPlaying) {
        await _audioHandler?.pause();
      } else {
        await _audioHandler?.play();
      }
    }
  }

  Future<void> seek(Duration position) async {
    _lastEmittedAudioPos = position;
    _lastEmittedVideoPos = position;
    if (state.isVideoMode && !_isBackgroundAudioActive && !state.isAudioOnly) {
      await _videoController?.seekTo(position);
    } else {
      await _audioHandler?.seek(position);
    }
    state = state.copyWith(position: position);
  }

  Future<void> seekRelative(Duration delta) async {
    final newPos = state.position + delta;
    final clamped = Duration(
      milliseconds: newPos.inMilliseconds.clamp(0, state.duration.inMilliseconds),
    );
    await seek(clamped);
  }

  Future<void> setSpeed(double speed) async {
    if (state.isVideoMode && !_isBackgroundAudioActive && !state.isAudioOnly) {
      await _videoController?.setPlaybackSpeed(speed);
    } else {
      await _audioHandler?.setSpeed(speed);
    }
    state = state.copyWith(speed: speed);
  }

  /// Tính năng YouTube Premium: Chạm và giữ để tăng tốc lên 2x
  void start2xSpeed() {
    if (state.is2xSpeedActive) return;
    _savedSpeedBefore2x = state.speed;
    setSpeed(2.0);
    state = state.copyWith(is2xSpeedActive: true);
  }

  /// Tính năng YouTube Premium: Thả tay ra trở lại tốc độ ban đầu
  void stop2xSpeed() {
    if (!state.is2xSpeedActive) return;
    setSpeed(_savedSpeedBefore2x);
    state = state.copyWith(is2xSpeedActive: false);
  }

  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    if (state.isVideoMode && !_isBackgroundAudioActive && !state.isAudioOnly) {
      await _videoController?.setVolume(v);
    } else {
      await _audioHandler?.player.setVolume(v);
    }
  }

  double get currentVolume {
    if (state.isVideoMode && !_isBackgroundAudioActive && !state.isAudioOnly) {
      return _videoController?.value.volume ?? 1.0;
    } else {
      return _audioHandler?.player.volume ?? 1.0;
    }
  }

  /// Chuyển đổi giữa chế độ phát Video và Chế độ chỉ nghe âm thanh (Tắt màn hình / tiết kiệm pin)
  Future<void> toggleAudioOnly() async {
    if (!state.isVideoMode) return;
    final newAudioOnly = !state.isAudioOnly;
    state = state.copyWith(isAudioOnly: newAudioOnly);

    if (newAudioOnly) {
      // Chuyển sang audio handler phát ngầm
      await _handoffVideoToBackgroundAudio();
    } else {
      // Chuyển lại về hiển thị video
      await _handoffBackgroundAudioToVideo();
    }
  }

  /// Kích hoạt màn hình nhỏ PiP trên Android & iOS
  Future<void> enterPip() async {
    if (!state.isVideoMode) return;
    try {
      final width = _videoController?.value.size.width.toInt() ?? 16;
      final height = _videoController?.value.size.height.toInt() ?? 9;
      state = state.copyWith(isPipActive: true);
      final success = await _pipChannel.invokeMethod<bool>('enterPip', {
        'width': width > 0 ? width : 16,
        'height': height > 0 ? height : 9,
      });
      if (success != true) {
        state = state.copyWith(isPipActive: false);
      }
    } catch (_) {
      state = state.copyWith(isPipActive: false);
    }
  }

  /// Cấu hình tự động vào PiP khi vuốt về Home trên Android 12+
  Future<void> updateAutoPip(bool enabled) async {
    if (!state.isVideoMode) return;
    try {
      final width = _videoController?.value.size.width.toInt() ?? 16;
      final height = _videoController?.value.size.height.toInt() ?? 9;
      await _pipChannel.invokeMethod('setAutoPip', {
        'enabled': enabled,
        'width': width > 0 ? width : 16,
        'height': height > 0 ? height : 9,
      });
    } catch (_) {}
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;

    int nextIndex;
    if (state.isShuffle && state.queue.length > 1) {
      final random = Random();
      do {
        nextIndex = random.nextInt(state.queue.length);
      } while (nextIndex == state.queueIndex && state.queue.length > 1);
    } else {
      nextIndex = state.queueIndex + 1;
      if (nextIndex >= state.queue.length) {
        if (state.repeatMode == PlaybackRepeatMode.all) {
          nextIndex = 0;
        } else {
          return;
        }
      }
    }
    await playLocalItem(state.queue[nextIndex], queue: state.queue, resumePosition: false);
  }

  Future<void> previous() async {
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (state.queue.isEmpty) return;
    int prevIndex = state.queueIndex - 1;
    if (prevIndex < 0) {
      prevIndex = state.queue.length - 1;
    }
    await playLocalItem(state.queue[prevIndex], queue: state.queue, resumePosition: false);
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void toggleRepeat() {
    final nextMode = switch (state.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
  }

  Future<void> _stopCurrent() async {
    await _saveCurrentPosition();
    _isBackgroundAudioActive = false;
    await updateAutoPip(false);
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoTick);
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
    }
    await _audioHandler?.stop();
  }
}
