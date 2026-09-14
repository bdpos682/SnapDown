import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
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

class GlobalPlaybackController extends Notifier<PlaybackStateModel> {
  static const MethodChannel _pipChannel = MethodChannel('com.snapvideo.snapdown/pip');

  late final MediaRepository _repository;
  SnapAudioHandler? _audioHandler;
  VideoPlayerController? _videoController;

  Timer? _positionSaveTimer;
  StreamSubscription? _audioStateSub;
  StreamSubscription? _audioPosSub;

  VideoPlayerController? get videoController => _videoController;

  @override
  PlaybackStateModel build() {
    _repository = MediaRepository();
    _initAudioHandler();

    ref.onDispose(() {
      _positionSaveTimer?.cancel();
      _audioStateSub?.cancel();
      _audioPosSub?.cancel();
      _videoController?.dispose();
      _videoController = null;
      _audioHandler?.stop();
    });

    return const PlaybackStateModel();
  }

  Future<void> _initAudioHandler() async {
    try {
      _audioHandler = globalAudioHandler;
    } catch (_) {
      _audioHandler = SnapAudioHandler();
    }

    _audioStateSub = _audioHandler!.playbackState.listen((ps) {
      if (!state.isVideoMode) {
        state = state.copyWith(
          isPlaying: ps.playing,
          bufferedPosition: ps.bufferedPosition,
          speed: ps.speed,
        );

        if (ps.processingState == AudioProcessingState.completed) {
          _handlePlaybackCompleted();
        }
      }
    });

    _audioPosSub = _audioHandler!.player.positionStream.listen((pos) {
      if (!state.isVideoMode) {
        state = state.copyWith(position: pos);
      }
    });

    _audioHandler!.player.durationStream.listen((dur) {
      if (!state.isVideoMode && dur != null) {
        state = state.copyWith(duration: dur);
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
    } else {
      await _audioHandler?.setMediaSource(
        uri: item.localPath,
        title: item.title,
        artist: item.artist,
        artworkUri: item.thumbnailPath != null ? Uri.file(item.thumbnailPath!).toString() : null,
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
      _videoController = VideoPlayerController.networkUrl(format.streamUrl);
      await _videoController!.initialize();

      state = state.copyWith(
        duration: _videoController!.value.duration,
        isPlaying: true,
      );

      _videoController!.addListener(_onVideoTick);
      await _videoController!.play();
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
    state = state.copyWith(
      isPlaying: val.isPlaying,
      position: val.position,
      duration: val.duration,
      bufferedPosition: val.buffered.isNotEmpty ? val.buffered.last.end : Duration.zero,
    );

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

      if (state.repeatMode == RepeatMode.one) {
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
    if (state.isVideoMode) {
      if (_videoController == null) return;
      if (_videoController!.value.isPlaying) {
        await _videoController!.pause();
        state = state.copyWith(isPlaying: false);
      } else {
        await _videoController!.play();
        state = state.copyWith(isPlaying: true);
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
    if (state.isVideoMode) {
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
    if (state.isVideoMode) {
      await _videoController?.setPlaybackSpeed(speed);
    } else {
      await _audioHandler?.setSpeed(speed);
    }
    state = state.copyWith(speed: speed);
  }

  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    if (state.isVideoMode) {
      await _videoController?.setVolume(v);
    } else {
      await _audioHandler?.player.setVolume(v);
    }
  }

  double get currentVolume {
    if (state.isVideoMode) {
      return _videoController?.value.volume ?? 1.0;
    } else {
      return _audioHandler?.player.volume ?? 1.0;
    }
  }

  /// Toggle Audio-Only mode for video playback.
  /// When active, video widget rendering is completely unmounted, saving GPU, CPU, and battery!
  void toggleAudioOnly() {
    state = state.copyWith(isAudioOnly: !state.isAudioOnly);
  }

  /// Triggers Native Picture-in-Picture on Android & iOS
  Future<void> enterPip() async {
    if (!state.isVideoMode) return;
    try {
      final width = _videoController?.value.size.width.toInt() ?? 16;
      final height = _videoController?.value.size.height.toInt() ?? 9;
      final success = await _pipChannel.invokeMethod<bool>('enterPip', {
        'width': width > 0 ? width : 16,
        'height': height > 0 ? height : 9,
      });
      state = state.copyWith(isPipActive: success ?? false);
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
        if (state.repeatMode == RepeatMode.all) {
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
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
  }

  Future<void> _stopCurrent() async {
    await _saveCurrentPosition();
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoTick);
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
    }
    await _audioHandler?.stop();
  }
}
