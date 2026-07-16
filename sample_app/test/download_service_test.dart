import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sample_app/src/data/api_clients.dart';
import 'package:sample_app/src/data/app_database.dart';
import 'package:sample_app/src/data/download_service.dart';
import 'package:sample_app/src/data/wallpaper_repository.dart';
import 'package:sample_app/src/models/wallpaper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _wallpaper = Wallpaper(
  id: 'pexels:42',
  source: WallpaperSource.pexels,
  thumbUrl: 'https://images.pexels.com/photos/42/thumb.jpeg',
  fullUrl: 'https://images.pexels.com/photos/42/pexels-photo-42.jpeg',
  photographer: 'Jane',
  photographerUrl: '',
  pageUrl: '',
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late Directory tempDir;
  late int imageRequests;

  DownloadService service({int status = 200}) {
    final client = MockClient((request) async {
      if (request.url.host.contains('images.pexels.com')) {
        imageRequests++;
        return http.Response.bytes(
          List.filled(64, 7),
          status,
          request: request,
        );
      }
      return http.Response('{}', 200);
    });
    return DownloadService(
      database: db,
      repository: WallpaperRepository(
        unsplash: UnsplashClient(httpClient: client),
        pexels: PexelsClient(httpClient: client),
      ),
      httpClient: client,
      wallpaperDirProvider: () async => tempDir,
    );
  }

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    tempDir = await Directory.systemTemp.createTemp('wallify_test');
    imageRequests = 0;
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('downloads the CDN-resized rendition to disk and records it', () async {
    final path = await service().download(_wallpaper, category: 'Nature');

    final file = File(path);
    expect(await file.exists(), isTrue);
    expect(await file.length(), 64);
    expect(path.endsWith('.jpg'), isTrue);

    final row = await db.getDownload(_wallpaper.id);
    expect(row, isNotNull);
    expect(row!.filePath, path);
    expect(row.category, 'Nature');

    // No leftover partial file.
    expect(await File('$path.part').exists(), isFalse);
  });

  test('reuses an existing download instead of re-fetching', () async {
    final s = service();
    final first = await s.download(_wallpaper);
    final second = await s.download(_wallpaper);

    expect(second, first);
    expect(imageRequests, 1);
  });

  test('a failed download leaves no file and no database row', () async {
    await expectLater(
      service(status: 500).download(_wallpaper),
      throwsA(isA<HttpException>()),
    );

    expect(await db.getDownload(_wallpaper.id), isNull);
    expect(tempDir.listSync().whereType<File>(), isEmpty);
  });
}
