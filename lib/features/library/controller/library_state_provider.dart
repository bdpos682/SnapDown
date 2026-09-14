import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/models/media_item_model.dart';
import '../../../core/database/models/playlist_model.dart';
import '../../../core/database/repositories/media_repository.dart';

final audioLibraryProvider =
    AsyncNotifierProvider<AudioLibraryNotifier, List<MediaItemModel>>(
  AudioLibraryNotifier.new,
);

class AudioLibraryNotifier extends AsyncNotifier<List<MediaItemModel>> {
  final MediaRepository _repository = MediaRepository();
  StreamSubscription? _sub;

  @override
  Future<List<MediaItemModel>> build() async {
    _sub?.cancel();
    _sub = _repository.changesStream.listen((_) => ref.invalidateSelf());
    ref.onDispose(() => _sub?.cancel());
    return await _repository.getAudioItems();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getAudioItems());
  }
}

final videoLibraryProvider =
    AsyncNotifierProvider<VideoLibraryNotifier, List<MediaItemModel>>(
  VideoLibraryNotifier.new,
);

class VideoLibraryNotifier extends AsyncNotifier<List<MediaItemModel>> {
  final MediaRepository _repository = MediaRepository();
  StreamSubscription? _sub;

  @override
  Future<List<MediaItemModel>> build() async {
    _sub?.cancel();
    _sub = _repository.changesStream.listen((_) => ref.invalidateSelf());
    ref.onDispose(() => _sub?.cancel());
    return await _repository.getVideoItems();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getVideoItems());
  }
}

final playlistListProvider =
    AsyncNotifierProvider<PlaylistListNotifier, List<PlaylistModel>>(
  PlaylistListNotifier.new,
);

class PlaylistListNotifier extends AsyncNotifier<List<PlaylistModel>> {
  final MediaRepository _repository = MediaRepository();
  StreamSubscription? _sub;

  @override
  Future<List<PlaylistModel>> build() async {
    _sub?.cancel();
    _sub = _repository.changesStream.listen((_) => ref.invalidateSelf());
    ref.onDispose(() => _sub?.cancel());
    return await _repository.getPlaylists();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getPlaylists());
  }
}
