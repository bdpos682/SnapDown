import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database_service.dart';
import '../models/media_item_model.dart';
import '../models/playlist_model.dart';

class MediaRepository {
  static final MediaRepository _instance = MediaRepository._internal();
  factory MediaRepository({DatabaseService? dbService}) {
    if (dbService != null) return MediaRepository._internal(dbService: dbService);
    return _instance;
  }

  final DatabaseService _dbService;
  final StreamController<void> _changesController = StreamController<void>.broadcast();

  MediaRepository._internal({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  Stream<void> get changesStream => _changesController.stream;

  void _notify() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  Future<Database> get _db => _dbService.database;

  Future<void> insertMedia(MediaItemModel item) async {
    final db = await _db;
    await db.insert(
      'media_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
  }

  Future<void> updateMedia(MediaItemModel item) async {
    final db = await _db;
    await db.update(
      'media_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    _notify();
  }

  Future<MediaItemModel?> getMediaById(String id) async {
    final db = await _db;
    final results = await db.query(
      'media_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return MediaItemModel.fromMap(results.first);
  }

  Future<List<MediaItemModel>> getAllMedia({String? mediaType}) async {
    final db = await _db;
    final results = await db.query(
      'media_items',
      where: mediaType != null ? 'media_type = ?' : null,
      whereArgs: mediaType != null ? [mediaType] : null,
      orderBy: 'downloaded_at DESC',
    );
    return results.map((m) => MediaItemModel.fromMap(m)).toList();
  }

  Stream<List<MediaItemModel>> watchAllMedia({String? mediaType}) async* {
    yield await getAllMedia(mediaType: mediaType);
    await for (final _ in changesStream) {
      yield await getAllMedia(mediaType: mediaType);
    }
  }

  Future<List<MediaItemModel>> getAudioItems() => getAllMedia(mediaType: 'audio');

  Future<List<MediaItemModel>> getVideoItems() => getAllMedia(mediaType: 'video');

  Future<List<MediaItemModel>> getFavorites({String? mediaType}) async {
    final db = await _db;
    final where = mediaType != null ? 'is_favorite = 1 AND media_type = ?' : 'is_favorite = 1';
    final whereArgs = mediaType != null ? [mediaType] : null;

    final results = await db.query(
      'media_items',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'downloaded_at DESC',
    );
    return results.map((m) => MediaItemModel.fromMap(m)).toList();
  }

  Future<List<MediaItemModel>> getRecentlyAdded({int limit = 10}) async {
    final db = await _db;
    final results = await db.query(
      'media_items',
      orderBy: 'downloaded_at DESC',
      limit: limit,
    );
    return results.map((m) => MediaItemModel.fromMap(m)).toList();
  }

  Future<List<MediaItemModel>> getRecentlyPlayed({int limit = 10}) async {
    final db = await _db;
    final results = await db.query(
      'media_items',
      where: 'last_played_at IS NOT NULL',
      orderBy: 'last_played_at DESC',
      limit: limit,
    );
    return results.map((m) => MediaItemModel.fromMap(m)).toList();
  }

  Future<List<MediaItemModel>> getContinueListening({int limit = 5}) async {
    final db = await _db;
    final results = await db.query(
      'media_items',
      where: 'media_type = ? AND last_position_ms > 0 AND is_completed = 0',
      whereArgs: ['audio'],
      orderBy: 'last_played_at DESC',
      limit: limit,
    );
    return results.map((m) => MediaItemModel.fromMap(m)).toList();
  }

  Future<List<MediaItemModel>> getContinueWatching({int limit = 5}) async {
    final db = await _db;
    final results = await db.query(
      'media_items',
      where: 'media_type = ? AND last_position_ms > 0 AND is_completed = 0',
      whereArgs: ['video'],
      orderBy: 'last_played_at DESC',
      limit: limit,
    );
    return results.map((m) => MediaItemModel.fromMap(m)).toList();
  }

  Future<void> updatePlaybackPosition({
    required String id,
    required int positionMs,
    bool isCompleted = false,
  }) async {
    final db = await _db;
    await db.update(
      'media_items',
      {
        'last_position_ms': positionMs,
        'is_completed': isCompleted ? 1 : 0,
        'last_played_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> recordPlayStarted(String id) async {
    final db = await _db;
    await db.rawUpdate('''
      UPDATE media_items 
      SET play_count = play_count + 1, last_played_at = ?
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), id]);
  }

  Future<bool> toggleFavorite(String id) async {
    final db = await _db;
    final item = await getMediaById(id);
    if (item == null) return false;
    final newStatus = !item.isFavorite;
    await db.update(
      'media_items',
      {'is_favorite': newStatus ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
    return newStatus;
  }

  Future<void> deleteMedia(String id) async {
    final db = await _db;
    await db.delete(
      'media_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
  }

  // =================== PLAYLIST METHODS ===================

  Future<PlaylistModel> createPlaylist(String name, {String? description}) async {
    final db = await _db;
    final playlist = PlaylistModel(
      id: const Uuid().v4(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
      itemCount: 0,
    );

    await db.insert(
      'playlists',
      playlist.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
    return playlist;
  }

  Future<List<PlaylistModel>> getPlaylists() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT p.*, COUNT(pi.media_id) as item_count
      FROM playlists p
      LEFT JOIN playlist_items pi ON p.id = pi.playlist_id
      GROUP BY p.id
      ORDER BY p.created_at DESC
    ''');
    return results.map((m) => PlaylistModel.fromMap(m)).toList();
  }

  Future<void> deletePlaylist(String playlistId) async {
    final db = await _db;
    await db.delete('playlist_items', where: 'playlist_id = ?', whereArgs: [playlistId]);
    await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
    _notify();
  }

  Future<void> addMediaToPlaylist(String playlistId, String mediaId) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM playlist_items WHERE playlist_id = ?',
      [playlistId],
    )) ?? 0;

    await db.insert(
      'playlist_items',
      {
        'playlist_id': playlistId,
        'media_id': mediaId,
        'position': count,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _notify();
  }

  Future<void> removeMediaFromPlaylist(String playlistId, String mediaId) async {
    final db = await _db;
    await db.delete(
      'playlist_items',
      where: 'playlist_id = ? AND media_id = ?',
      whereArgs: [playlistId, mediaId],
    );
    _notify();
  }

  Future<List<MediaItemModel>> getPlaylistItems(String playlistId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT m.* FROM media_items m
      INNER JOIN playlist_items pi ON m.id = pi.media_id
      WHERE pi.playlist_id = ?
      ORDER BY pi.position ASC
    ''', [playlistId]);
    return results.map((m) => MediaItemModel.fromMap(m)).toList();
  }

  Future<List<String>> getPlaylistsContainingMedia(String mediaId) async {
    final db = await _db;
    final results = await db.query(
      'playlist_items',
      columns: ['playlist_id'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
    return results.map((r) => r['playlist_id'] as String).toList();
  }

  Future<List<MediaItemModel>> searchMedia(String query, {String? mediaType}) async {
    final db = await _db;
    final sanitizedQuery = '%$query%';
    final where = mediaType != null
        ? '(title LIKE ? OR artist LIKE ?) AND media_type = ?'
        : '(title LIKE ? OR artist LIKE ?)';
    final whereArgs = mediaType != null
        ? [sanitizedQuery, sanitizedQuery, mediaType]
        : [sanitizedQuery, sanitizedQuery];

    final results = await db.query(
      'media_items',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'downloaded_at DESC',
    );
    return results.map((m) => MediaItemModel.fromMap(m)).toList();
  }
}
