import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sample_app/src/data/api_clients.dart';
import 'package:sample_app/src/data/wallpaper_repository.dart';
import 'package:sample_app/src/models/wallpaper.dart';

MockClient _mockClient({
  int unsplashStatus = 200,
  int pexelsStatus = 200,
}) {
  return MockClient((request) async {
    if (request.url.host == 'api.unsplash.com') {
      if (unsplashStatus != 200) {
        return http.Response('error', unsplashStatus);
      }
      final items = List.generate(
        3,
        (i) => {
          'id': 'u$i',
          'urls': {'small': 's', 'full': 'f'},
          'links': {'html': 'h'},
          'user': {'name': 'U $i', 'links': {'html': ''}},
        },
      );
      final body = request.url.path == '/photos'
          ? json.encode(items)
          : json.encode({'results': items});
      return http.Response(body, 200);
    }
    if (request.url.host == 'api.pexels.com') {
      if (pexelsStatus != 200) {
        return http.Response('error', pexelsStatus);
      }
      final items = List.generate(
        3,
        (i) => {
          'id': i,
          'url': 'page',
          'photographer': 'P $i',
          'photographer_url': '',
          'src': {'medium': 'm', 'original': 'o'},
        },
      );
      return http.Response(json.encode({'photos': items}), 200);
    }
    return http.Response('not found', 404);
  });
}

WallpaperRepository _repository(MockClient client) => WallpaperRepository(
      unsplash: UnsplashClient(httpClient: client),
      pexels: PexelsClient(httpClient: client),
    );

void main() {
  const featured = WallpaperCategory('Featured', null);
  const nature = WallpaperCategory('Nature', 'nature');

  test('interleaves results from both sources', () async {
    final repo = _repository(_mockClient());

    final page = await repo.fetchPage(nature, page: 1);

    expect(page, hasLength(6));
    expect(page[0].source, WallpaperSource.unsplash);
    expect(page[1].source, WallpaperSource.pexels);
    expect(page[2].source, WallpaperSource.unsplash);
  });

  test('curated feeds work with null query', () async {
    final repo = _repository(_mockClient());
    final page = await repo.fetchPage(featured, page: 1);
    expect(page, hasLength(6));
  });

  test('falls back to the healthy source when one provider fails', () async {
    final repo = _repository(_mockClient(unsplashStatus: 429));

    final page = await repo.fetchPage(nature, page: 1);

    expect(page, hasLength(3));
    expect(page.every((w) => w.source == WallpaperSource.pexels), isTrue);
  });

  test('throws when every provider fails', () async {
    final repo = _repository(_mockClient(unsplashStatus: 500, pexelsStatus: 500));

    expect(
      () => repo.fetchPage(nature, page: 1),
      throwsA(isA<ApiException>()),
    );
  });

  test('source filter queries a single provider', () async {
    final repo = _repository(_mockClient(unsplashStatus: 500));

    final page = await repo.fetchPage(
      nature,
      page: 1,
      filter: PhotoSourceFilter.pexels,
    );

    expect(page.every((w) => w.source == WallpaperSource.pexels), isTrue);
  });
}
