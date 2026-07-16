import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/wallpaper.dart';

/// SQLite storage for app settings and downloaded wallpapers.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static const _version = 2;

  /// Opens (and migrates) the database. Pass [path] to use a custom location,
  /// e.g. `inMemoryDatabasePath` in tests.
  static Future<AppDatabase> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'wallify.db');
    final db = await openDatabase(
      dbPath,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            source TEXT NOT NULL,
            thumb_url TEXT NOT NULL,
            full_url TEXT NOT NULL,
            photographer TEXT NOT NULL,
            photographer_url TEXT,
            page_url TEXT,
            avg_color TEXT,
            width INTEGER,
            height INTEGER,
            file_path TEXT,
            category TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // SQLite can't drop NOT NULL: rebuild the table.
          await db.execute('ALTER TABLE downloads RENAME TO downloads_v1');
          await db.execute('''
            CREATE TABLE downloads (
              id TEXT PRIMARY KEY,
              source TEXT NOT NULL,
              thumb_url TEXT NOT NULL,
              full_url TEXT NOT NULL,
              photographer TEXT NOT NULL,
              photographer_url TEXT,
              page_url TEXT,
              avg_color TEXT,
              width INTEGER,
              height INTEGER,
              file_path TEXT,
              category TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute(
              'INSERT INTO downloads SELECT * FROM downloads_v1');
          await db.execute('DROP TABLE downloads_v1');
        }
      },
    );
    return AppDatabase._(db);
  }

  Future<void> close() => _db.close();

  // --- Settings -------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final rows = await _db.query('settings',
        columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) => _db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  // --- Downloads ------------------------------------------------------------

  Future<void> insertDownload(Wallpaper wallpaper,
          {String? filePath, String? category, int? createdAtMillis}) =>
      _db.insert(
        'downloads',
        wallpaper.toDbMap(
            filePath: filePath,
            category: category,
            createdAtMillis: createdAtMillis),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Raw REPLACE insert of a full downloads row (used by cloud merge).
  Future<void> upsertDownloadRow(Map<String, Object?> row) => _db.insert(
        'downloads',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> deleteDownload(String id) =>
      _db.delete('downloads', where: 'id = ?', whereArgs: [id]);

  Future<DownloadedWallpaper?> getDownload(String id) async {
    final rows =
        await _db.query('downloads', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : DownloadedWallpaper.fromDbMap(rows.first);
  }

  Future<List<DownloadedWallpaper>> getAllDownloads() async {
    final rows = await _db.query('downloads', orderBy: 'created_at DESC');
    return rows.map(DownloadedWallpaper.fromDbMap).toList();
  }
}
