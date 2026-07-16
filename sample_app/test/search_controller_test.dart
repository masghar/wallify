import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sample_app/src/data/api_clients.dart';
import 'package:sample_app/src/data/app_database.dart';
import 'package:sample_app/src/data/wallpaper_repository.dart';
import 'package:sample_app/src/state/explore_controller.dart';
import 'package:sample_app/src/state/settings_controller.dart';
import 'package:sample_app/src/state/wallpaper_search_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

MockClient _mockClient() {
  return MockClient((request) async {
    if (request.url.host == 'api.unsplash.com') {
      final items = List.generate(
        2,
        (i) => {
          'id': 'u$i',
          'urls': {'small': 's', 'full': 'f'},
          'links': {'html': 'h'},
          'user': {'name': 'U $i', 'links': {'html': ''}},
        },
      );
      return http.Response(json.encode({'results': items}), 200);
    }
    final items = List.generate(
      2,
      (i) => {
        'id': i,
        'url': 'page',
        'photographer': 'P $i',
        'photographer_url': '',
        'src': {'medium': 'm', 'original': 'o'},
      },
    );
    return http.Response(json.encode({'photos': items}), 200);
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late WallpaperSearchController controller;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    final client = _mockClient();
    controller = WallpaperSearchController(
      repository: WallpaperRepository(
        unsplash: UnsplashClient(httpClient: client),
        pexels: PexelsClient(httpClient: client),
      ),
      database: db,
      settings: SettingsController(db),
    );
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('search fills the feed and records the query as recent', () async {
    await controller.search('aurora');

    expect(controller.feed.status, FeedStatus.ready);
    expect(controller.feed.items, hasLength(4));
    expect(controller.recents, ['aurora']);

    // Persisted to the database, not just memory.
    final raw = await db.getSetting('recent_searches');
    expect(json.decode(raw!), ['aurora']);
  });

  test('recents dedupe, newest first, capped', () async {
    await controller.search('one');
    await controller.search('two');
    await controller.search('ONE');

    expect(controller.recents, ['ONE', 'two']);
  });

  test('clearing the query resets the feed', () async {
    await controller.search('aurora');
    controller.onQueryChanged('');

    expect(controller.feed.status, FeedStatus.initial);
    expect(controller.feed.items, isEmpty);
  });

  test('clearRecents empties list and storage', () async {
    await controller.search('aurora');
    await controller.clearRecents();

    expect(controller.recents, isEmpty);
    expect(json.decode((await db.getSetting('recent_searches'))!), isEmpty);
  });
}
