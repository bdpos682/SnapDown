import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class SnapAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  SnapAudioHandler() {
    _initAudioSession();
    _listenToPlaybackState();
    _listenToPositionUpdates();
  }

  AudioPlayer get player => _player;

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Handle audio interruptions (phone calls, Siri, alarms)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _player.pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            _player.play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    // Handle headphones being unplugged / bluetooth disconnect
    session.becomingNoisyEventStream.listen((_) {
      _player.pause();
    });
  }

  void _listenToPlaybackState() {
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      AudioProcessingState audioProcessingState;
      switch (processingState) {
        case ProcessingState.idle:
          audioProcessingState = AudioProcessingState.idle;
          break;
        case ProcessingState.loading:
          audioProcessingState = AudioProcessingState.loading;
          break;
        case ProcessingState.buffering:
          audioProcessingState = AudioProcessingState.buffering;
          break;
        case ProcessingState.ready:
          audioProcessingState = AudioProcessingState.ready;
          break;
        case ProcessingState.completed:
          audioProcessingState = AudioProcessingState.completed;
          break;
      }

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: audioProcessingState,
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });
  }

  void _listenToPositionUpdates() {
    _player.durationStream.listen((dur) {
      if (dur != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: dur));
      }
    });
  }

  Future<void> setMediaSource({
    required String uri,
    required String title,
    required String artist,
    String? artworkUri,
    Duration? duration,
    bool isLocal = true,
  }) async {
    Uri? artUri;
    if (artworkUri != null && artworkUri.trim().isNotEmpty) {
      final clean = artworkUri.trim();
      if (clean.startsWith('http://') || clean.startsWith('https://')) {
        artUri = Uri.tryParse(clean);
      } else if (clean.startsWith('file://')) {
        artUri = Uri.tryParse(clean);
      } else {
        final f = File(clean);
        if (f.existsSync()) {
          artUri = Uri.file(f.path);
        }
      }
    }

    final item = MediaItem(
      id: uri,
      title: title,
      artist: artist,
      artUri: artUri,
      duration: duration,
    );
    mediaItem.add(item);

    if (isLocal) {
      await _player.setFilePath(uri);
    } else {
      await _player.setUrl(uri);
    }
  }

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    await session.setActive(true);
    return _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    final session = await AudioSession.instance;
    await session.setActive(false);
    return _player.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> fastForward() => seek(_player.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() => seek(_player.position - const Duration(seconds: 10));
}
