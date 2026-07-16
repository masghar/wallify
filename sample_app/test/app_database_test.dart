import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sample_app/src/data/app_database.dart';
import 'package:sample_app/src/models/wallpaper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Helper to build a test Wallpaper with the given id.
Wallpaper _wallpaper(String id) => Wallpaper(
      id: id,
      source: id.startsWith('unsplash') ? WallpaperSource.unsplash : WallpaperSource.pexels,
      thumbUrl: 'thumb',
      fullUrl: 'full',
      photographer: 'photographer',
      photographerUrl: 'purl',
      pageUrl: 'page',
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  test('settings roundtrip and overwrite', () async {
    expect(await db.getSetting('theme_mode'), isNull);

    await db.setSetting('theme_mode', 'dark');
    expect(await db.getSetting('theme_mode'), 'dark');

    await db.setSetting('theme_mode', 'light');
    expect(await db.getSetting('theme_mode'), 'light');
  });

  test('downloads insert, query, delete', () async {
    const wallpaper = Wallpaper(
      id: 'unsplash:abc',
      source: WallpaperSource.unsplash,
      thumbUrl: 'thumb',
      fullUrl: 'full',
      photographer: 'Jane',
      photographerUrl: 'purl',
      pageUrl: 'page',
    );

    await db.insertDownload(wallpaper,
        filePath: '/tmp/a.jpg', category: 'Nature');

    final one = await db.getDownload('unsplash:abc');
    expect(one, isNotNull);
    expect(one!.filePath, '/tmp/a.jpg');
    expect(one.category, 'Nature');
    expect(one.wallpaper.photographer, 'Jane');

    final all = await db.getAllDownloads();
    expect(all, hasLength(1));

    await db.deleteDownload('unsplash:abc');
    expect(await db.getDownload('unsplash:abc'), isNull);
    expect(await db.getAllDownloads(), isEmpty);
  });

  test('re-inserting same id replaces the row', () async {
    const wallpaper = Wallpaper(
      id: 'pexels:1',
      source: WallpaperSource.pexels,
      thumbUrl: 't',
      fullUrl: 'f',
      photographer: 'p',
      photographerUrl: '',
      pageUrl: '',
    );

    await db.insertDownload(wallpaper, filePath: '/tmp/1.jpg');
    await db.insertDownload(wallpaper, filePath: '/tmp/2.jpg');

    final all = await db.getAllDownloads();
    expect(all, hasLength(1));
    expect(all.single.filePath, '/tmp/2.jpg');
  });

  group('schema v2', () {
    test('stores and returns a record with null file_path', () async {
      final db = await AppDatabase.open(path: inMemoryDatabasePath);
      addTearDown(db.close);
      final w = _wallpaper('unsplash:cloud1');
      await db.upsertDownloadRow(
          w.toDbMap(filePath: null, createdAtMillis: 1234));
      final all = await db.getAllDownloads();
      expect(all.single.filePath, isNull);
      expect(all.single.hasLocalFile, isFalse);
      expect(all.single.createdAt.millisecondsSinceEpoch, 1234);
    });

    test('migrates a v1 database keeping existing rows', () async {
      // Build a v1 database by hand, then reopen through AppDatabase.
      final dir = await Directory.systemTemp.createTemp('wallify_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = p.join(dir.path, 'v1.db');
      final raw = await openDatabase(file, version: 1,
          onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)
        ''');
        await db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY, source TEXT NOT NULL,
            thumb_url TEXT NOT NULL, full_url TEXT NOT NULL,
            photographer TEXT NOT NULL, photographer_url TEXT, page_url TEXT,
            avg_color TEXT, width INTEGER, height INTEGER,
            file_path TEXT NOT NULL, category TEXT, created_at INTEGER NOT NULL
          )
        ''');
        await db.insert('downloads', {
          'id': 'pexels:1', 'source': 'pexels', 'thumb_url': 't',
          'full_url': 'f', 'photographer': 'p', 'file_path': '/old/file.jpg',
          'created_at': 99,
        });
      });
      await raw.close();

      final db = await AppDatabase.open(path: file);
      addTearDown(db.close);
      final all = await db.getAllDownloads();
      expect(all.single.filePath, '/old/file.jpg');
      // v2 accepts null file_path after migration:
      await db.upsertDownloadRow(
          _wallpaper('unsplash:new').toDbMap(filePath: null, createdAtMillis: 1));
      expect((await db.getAllDownloads()).length, 2);
    });
  });
}
