import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/data/app_database.dart';
import 'package:sample_app/src/data/download_sync_service.dart';
import 'package:sample_app/src/models/wallpaper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/in_memory_download_store.dart';

Wallpaper _wallpaper(String id) => Wallpaper(
      id: id,
      source: WallpaperSource.pexels,
      thumbUrl: 'https://cdn/thumb.jpg',
      fullUrl: 'https://cdn/full.jpg',
      photographer: 'Photographer',
      photographerUrl: 'https://cdn/ph',
      pageUrl: 'https://cdn/page',
      avgColor: '#112233',
      width: 100,
      height: 150,
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late InMemoryDownloadStore store;
  String? uid = 'user-1';
  late DownloadSyncService sync;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    store = InMemoryDownloadStore();
    uid = 'user-1';
    sync = DownloadSyncService(
      database: db,
      store: store,
      currentUid: () => uid,
    );
  });

  tearDown(() => db.close());

  test('uploadRecord mirrors a download into the cloud store', () async {
    await db.insertDownload(_wallpaper('pexels:1'),
        filePath: '/f.jpg', category: 'nature', createdAtMillis: 5);
    final d = (await db.getAllDownloads()).single;
    await sync.uploadRecord(d);
    final doc = store.docs['user-1']!['pexels:1']!;
    expect(doc['thumb_url'], 'https://cdn/thumb.jpg');
    expect(doc['category'], 'nature');
    expect(doc['created_at'], 5);
    expect(doc.containsKey('file_path'), isFalse); // device-local, never synced
  });

  test('deleteRecord removes the cloud doc', () async {
    store.docs['user-1'] = {
      'pexels:1': {'thumb_url': 't'},
    };
    await sync.deleteRecord('pexels:1');
    expect(store.docs['user-1'], isEmpty);
  });

  test('merge pulls cloud-only records in with null file_path', () async {
    store.docs['user-1'] = {
      'unsplash:9': _wallpaper('unsplash:9').toDbMap(createdAtMillis: 7)
        ..remove('file_path'),
    };
    final restored = await sync.merge();
    expect(restored, 1);
    final local = (await db.getAllDownloads()).single;
    expect(local.wallpaper.id, 'unsplash:9');
    expect(local.hasLocalFile, isFalse);
    expect(local.createdAt.millisecondsSinceEpoch, 7);
  });

  test('merge pushes local-only records up', () async {
    await db.insertDownload(_wallpaper('pexels:2'), filePath: '/f2.jpg');
    await sync.merge();
    expect(store.docs['user-1']!.keys, ['pexels:2']);
  });

  test('merge is idempotent and keeps local file paths', () async {
    await db.insertDownload(_wallpaper('pexels:3'), filePath: '/f3.jpg');
    await sync.merge();
    final restored = await sync.merge();
    expect(restored, 0);
    expect((await db.getAllDownloads()).single.filePath, '/f3.jpg');
    expect(store.docs['user-1']!.length, 1);
  });

  test('merge skips malformed cloud docs and keeps the good ones', () async {
    store.docs['user-1'] = {
      'unsplash:good': _wallpaper('unsplash:good').toDbMap(createdAtMillis: 7)
        ..remove('file_path'),
      'bad:doc': {
        'source': 'notasource',
        'thumb_url': 't',
        'full_url': 'f',
        'photographer': 'p',
        'created_at': 1,
      },
      'bad:doc2': {
        'unexpected_column': 'x',
        'source': 'pexels',
      },
    };
    final restored = await sync.merge();
    expect(restored, 1);
    final all = await db.getAllDownloads();
    expect(all.single.wallpaper.id, 'unsplash:good');
  });

  test('everything is a no-op when signed out', () async {
    uid = null;
    await db.insertDownload(_wallpaper('pexels:4'), filePath: '/f4.jpg');
    await sync.uploadRecord((await db.getAllDownloads()).single);
    await sync.deleteRecord('pexels:4');
    expect(await sync.merge(), 0);
    expect(store.docs, isEmpty);
  });
}
