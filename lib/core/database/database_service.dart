import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'snapdown_media.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. media_items table
    await db.execute('''
      CREATE TABLE media_items (
        id TEXT PRIMARY KEY,
        source_url TEXT NOT NULL,
        source_platform TEXT NOT NULL,
        remote_id TEXT NOT NULL,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        description TEXT,
        media_type TEXT NOT NULL,
        local_path TEXT NOT NULL,
        thumbnail_path TEXT,
        thumbnail_url TEXT,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        audio_codec TEXT,
        video_codec TEXT,
        container TEXT NOT NULL DEFAULT 'mp4',
        bitrate INTEGER,
        width INTEGER,
        height INTEGER,
        fps INTEGER,
        file_size INTEGER NOT NULL DEFAULT 0,
        downloaded_at TEXT NOT NULL,
        last_played_at TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        play_count INTEGER NOT NULL DEFAULT 0,
        last_position_ms INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Indices for speed
    await db.execute('CREATE INDEX idx_media_type ON media_items(media_type)');
    await db.execute('CREATE INDEX idx_downloaded_at ON media_items(downloaded_at DESC)');
    await db.execute('CREATE INDEX idx_is_favorite ON media_items(is_favorite)');
    await db.execute('CREATE INDEX idx_last_played ON media_items(last_played_at DESC)');

    // 2. playlists table
    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 3. playlist_items table
    await db.execute('''
      CREATE TABLE playlist_items (
        playlist_id TEXT NOT NULL,
        media_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, media_id),
        FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE,
        FOREIGN KEY (media_id) REFERENCES media_items (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
