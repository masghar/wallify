import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sample_app/src/data/api_clients.dart';
import 'package:sample_app/src/data/app_database.dart';
import 'package:sample_app/src/data/download_service.dart';
import 'package:sample_app/src/data/download_sync_service.dart';
import 'package:sample_app/src/data/wallpaper_repository.dart';
import 'package:sample_app/src/models/wallpaper.dart';
import 'package:sample_app/src/state/downloads_controller.dart';
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
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late Directory tempDir;
  late InMemoryDownloadStore store;
  late DownloadsController controller;

  DownloadService buildDownloadService(Directory dir) {
    final client =
        MockClient((_) async => http.Response.bytes([1, 2, 3], 200));
    return DownloadService(
      database: db,
      repository: WallpaperRepository(
        unsplash: UnsplashClient(httpClient: client),
        pexels: PexelsClient(httpClient: client),
      ),
      httpClient: client,
      wallpaperDirProvider: () async => dir,
    );
  }

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    tempDir = await Directory.systemTemp.createTemp('wallify_dl_test');
    store = InMemoryDownloadStore();
    controller = DownloadsController(
      database: db,
      downloadService: buildDownloadService(tempDir),
      syncService: DownloadSyncService(
        database: db,
        store: store,
        currentUid: () => 'user-1',
      ),
    );
    await controller.load();
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('download writes through to the cloud store', () async {
    await controller.download(_wallpaper('pexels:1'), category: 'nature');
    await pumpEventQueue();
    expect(store.docs['user-1']!.keys, contains('pexels:1'));
  });

  test('delete removes the cloud record too', () async {
    await controller.download(_wallpaper('pexels:1'));
    await pumpEventQueue();
    await controller.delete(controller.downloads.single);
    await pumpEventQueue();
    expect(store.docs['user-1'], isEmpty);
    expect(controller.downloads, isEmpty);
  });

  test('redownload fills in the file path of a restored record', () async {
    await db.upsertDownloadRow(
        _wallpaper('pexels:2').toDbMap(createdAtMillis: 42));
    await controller.load();
    expect(controller.downloads.single.hasLocalFile, isFalse);

    await controller.redownload(controller.downloads.single);
    final after = controller.downloads.single;
    expect(after.hasLocalFile, isTrue);
    expect(after.createdAt.millisecondsSinceEpoch, 42,
        reason: 'redownload keeps the original save time');
  });

  test('cloud failure never fails the local operation', () async {
    final failing = _ThrowingStore();
    final c2 = DownloadsController(
      database: db,
      downloadService: buildDownloadService(tempDir),
      syncService: DownloadSyncService(
        database: db,
        store: failing,
        currentUid: () => 'user-1',
      ),
    );
    await c2.load();
    await c2.download(_wallpaper('pexels:3'));
    await pumpEventQueue();
    expect(c2.downloads.single.wallpaper.id, 'pexels:3');
  });
}

class _ThrowingStore implements CloudDownloadStore {
  @override
  Future<Map<String, Map<String, Object?>>> fetchAll(String uid) async =>
      throw Exception('offline');
  @override
  Future<void> put(String uid, String id, Map<String, Object?> data) async =>
      throw Exception('offline');
  @override
  Future<void> delete(String uid, String id) async =>
      throw Exception('offline');
}
