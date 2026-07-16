import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sample_app/src/data/api_clients.dart';
import 'package:sample_app/src/data/app_database.dart';
import 'package:sample_app/src/data/auth_service.dart';
import 'package:sample_app/src/data/download_service.dart';
import 'package:sample_app/src/data/download_sync_service.dart';
import 'package:sample_app/src/data/wallpaper_repository.dart';
import 'package:sample_app/src/models/wallpaper.dart';
import 'package:sample_app/src/state/auth_controller.dart';
import 'package:sample_app/src/state/downloads_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_auth_service.dart';
import 'fakes/in_memory_download_store.dart';

Wallpaper _wallpaper(String id) => Wallpaper(
      id: id,
      source: WallpaperSource.unsplash,
      thumbUrl: 'https://cdn/t.jpg',
      fullUrl: 'https://cdn/f.jpg',
      photographer: 'P',
      photographerUrl: '',
      pageUrl: '',
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late Directory tempDir;
  late FakeAuthService auth;
  late InMemoryDownloadStore store;
  late DownloadsController downloads;
  late AuthController controller;

  const user = AppUser(uid: 'user-1', displayName: 'Test', email: 't@x.com');

  DownloadService buildDownloadService(Directory dir) {
    final client = MockClient((_) async => http.Response.bytes([1], 200));
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
    tempDir = await Directory.systemTemp.createTemp('wallify_auth_test');
    auth = FakeAuthService();
    store = InMemoryDownloadStore();
    final sync = DownloadSyncService(
      database: db,
      store: store,
      currentUid: () => auth.currentUser?.uid,
    );
    downloads = DownloadsController(
      database: db,
      downloadService: buildDownloadService(tempDir),
      syncService: sync,
    );
    await downloads.load();
    controller = AuthController(
      auth: auth,
      sync: sync,
      database: db,
      downloads: downloads,
    );
    await controller.init();
  });

  tearDown(() async {
    controller.dispose();
    auth.dispose();
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('sign-in merges cloud records into the local library', () async {
    store.docs['user-1'] = {
      'unsplash:9': _wallpaper('unsplash:9').toDbMap(createdAtMillis: 7)
        ..remove('file_path'),
    };
    auth.nextSignInResult = user;

    expect(await controller.signIn(), isTrue);
    // The merge runs on the unawaited auth-stream path through several real
    // sqflite_common_ffi round trips; give it enough ticks to settle.
    await pumpEventQueue(times: 200);

    expect(controller.user?.uid, 'user-1');
    expect(downloads.downloads.single.wallpaper.id, 'unsplash:9');
    expect(controller.lastSyncedAt, isNotNull);
    expect(await db.getSetting('last_synced_at'), isNotNull);
  });

  test('cancelled sign-in returns false and stays signed out', () async {
    auth.nextSignInResult = null;
    expect(await controller.signIn(), isFalse);
    expect(controller.user, isNull);
  });

  test('failed sign-in rethrows and stays signed out', () async {
    auth.nextSignInError = Exception('network');
    expect(() => controller.signIn(), throwsException);
    expect(controller.user, isNull);
  });

  test('sign-out clears the user but keeps local records', () async {
    // Cloud data must be present *before* sign-in so the sign-in merge picks
    // it up; the assertion is that it survives sign-out afterwards.
    store.docs['user-1'] = {
      'unsplash:9': _wallpaper('unsplash:9').toDbMap(createdAtMillis: 7)
        ..remove('file_path'),
    };
    auth.nextSignInResult = user;
    await controller.signIn();
    // The merge runs on the unawaited auth-stream path through several real
    // sqflite_common_ffi round trips; give it enough ticks to settle.
    await pumpEventQueue(times: 200);
    await controller.signOut();
    await pumpEventQueue();
    expect(controller.user, isNull);
    // merge already ran at sign-in; records stay local after sign-out
    expect(downloads.downloads, isNotEmpty);
  });

  test('already-signed-in user at startup triggers a merge', () async {
    store.docs['user-1'] = {
      'unsplash:5': _wallpaper('unsplash:5').toDbMap(createdAtMillis: 3)
        ..remove('file_path'),
    };
    await auth.emitSignIn(user);
    await pumpEventQueue(times: 200);
    expect(downloads.downloads.single.wallpaper.id, 'unsplash:5');
  });
}
