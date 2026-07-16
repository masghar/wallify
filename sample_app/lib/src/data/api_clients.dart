import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../models/wallpaper.dart';

/// Keep API calls snappy; a hung request should fail fast so the other
/// provider's results can still be shown.
const kApiTimeout = Duration(seconds: 12);

/// Thrown when a photo API returns an error response.
class ApiException implements Exception {
  const ApiException(this.source, this.statusCode, [this.message]);

  final WallpaperSource source;
  final int statusCode;
  final String? message;

  bool get isRateLimited => statusCode == 403 || statusCode == 429;

  @override
  String toString() =>
      'ApiException(${source.label}, HTTP $statusCode${message == null ? '' : ': $message'})';
}

class UnsplashClient {
  UnsplashClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _base = 'api.unsplash.com';
  final http.Client _http;

  Map<String, String> get _headers => const {
        'Authorization': 'Client-ID ${ApiKeys.unsplashAccessKey}',
        'Accept-Version': 'v1',
      };

  /// Editorial feed when [query] is null, otherwise a search.
  Future<List<Wallpaper>> fetch({String? query, int page = 1, int perPage = 15}) async {
    final Uri uri;
    if (query == null || query.isEmpty) {
      uri = Uri.https(_base, '/photos', {
        'page': '$page',
        'per_page': '$perPage',
        'order_by': 'popular',
      });
    } else {
      uri = Uri.https(_base, '/search/photos', {
        'query': query,
        'page': '$page',
        'per_page': '$perPage',
        'orientation': 'portrait',
      });
    }

    final response = await _http.get(uri, headers: _headers).timeout(kApiTimeout);
    if (response.statusCode != 200) {
      throw ApiException(WallpaperSource.unsplash, response.statusCode, response.body);
    }

    final decoded = json.decode(response.body);
    final List<dynamic> items =
        decoded is List ? decoded : (decoded['results'] as List<dynamic>? ?? const []);
    return items
        .whereType<Map<String, dynamic>>()
        .map(Wallpaper.fromUnsplashJson)
        .toList();
  }

  /// Unsplash API guidelines require hitting the download endpoint whenever a
  /// user downloads a photo. Failures are ignored on purpose.
  Future<void> trackDownload(Wallpaper wallpaper) async {
    final location = wallpaper.downloadLocation;
    if (location == null) return;
    try {
      await _http.get(Uri.parse(location), headers: _headers).timeout(kApiTimeout);
    } catch (_) {
      // Best-effort only.
    }
  }
}

class PexelsClient {
  PexelsClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  static const _base = 'api.pexels.com';
  final http.Client _http;

  Map<String, String> get _headers =>
      const {'Authorization': ApiKeys.pexelsApiKey};

  /// Curated feed when [query] is null, otherwise a search.
  Future<List<Wallpaper>> fetch({String? query, int page = 1, int perPage = 15}) async {
    final Uri uri;
    if (query == null || query.isEmpty) {
      uri = Uri.https(_base, '/v1/curated', {
        'page': '$page',
        'per_page': '$perPage',
      });
    } else {
      uri = Uri.https(_base, '/v1/search', {
        'query': query,
        'page': '$page',
        'per_page': '$perPage',
        'orientation': 'portrait',
      });
    }

    final response = await _http.get(uri, headers: _headers).timeout(kApiTimeout);
    if (response.statusCode != 200) {
      throw ApiException(WallpaperSource.pexels, response.statusCode, response.body);
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final items = decoded['photos'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Wallpaper.fromPexelsJson)
        .toList();
  }
}
