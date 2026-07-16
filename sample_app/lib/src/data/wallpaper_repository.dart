import '../models/wallpaper.dart';
import 'api_clients.dart';

/// Which providers to query.
enum PhotoSourceFilter { all, unsplash, pexels }

/// A category shown as a chip on the Explore screen. A null [query] means the
/// providers' curated/editorial feeds.
class WallpaperCategory {
  const WallpaperCategory(this.title, this.query);

  final String title;
  final String? query;

  static const List<WallpaperCategory> defaults = [
    WallpaperCategory('Featured', null),
    WallpaperCategory('Nature', 'nature landscape'),
    WallpaperCategory('Abstract', 'abstract background'),
    WallpaperCategory('Minimal', 'minimal wallpaper'),
    WallpaperCategory('Space', 'space stars galaxy'),
    WallpaperCategory('City', 'city skyline night'),
    WallpaperCategory('Mountains', 'mountains'),
    WallpaperCategory('Ocean', 'ocean sea'),
    WallpaperCategory('Animals', 'wild animals'),
    WallpaperCategory('Flowers', 'flowers macro'),
    WallpaperCategory('Cars', 'sports car'),
    WallpaperCategory('Dark', 'dark moody wallpaper'),
  ];
}

/// Fetches and merges wallpapers from Unsplash and Pexels.
class WallpaperRepository {
  WallpaperRepository({UnsplashClient? unsplash, PexelsClient? pexels})
      : _unsplash = unsplash ?? UnsplashClient(),
        _pexels = pexels ?? PexelsClient();

  final UnsplashClient _unsplash;
  final PexelsClient _pexels;

  /// Fetches one page for [category], interleaving results from both sources.
  ///
  /// If one provider fails (e.g. rate limited) but the other succeeds, the
  /// successful provider's results are returned. Throws only when every
  /// queried provider fails.
  Future<List<Wallpaper>> fetchPage(
    WallpaperCategory category, {
    required int page,
    PhotoSourceFilter filter = PhotoSourceFilter.all,
    int perSourceCount = 15,
  }) async {
    final futures = <Future<List<Wallpaper>>>[
      if (filter != PhotoSourceFilter.pexels)
        _unsplash.fetch(query: category.query, page: page, perPage: perSourceCount),
      if (filter != PhotoSourceFilter.unsplash)
        _pexels.fetch(query: category.query, page: page, perPage: perSourceCount),
    ];

    final results = await Future.wait(
      futures.map((f) => f.then<Object>((list) => list, onError: (Object e) => e)),
    );

    final lists = results.whereType<List<Wallpaper>>().toList();
    if (lists.isEmpty) {
      final firstError = results.firstWhere((r) => r is Exception, orElse: () => Exception('Unknown error'));
      throw firstError as Exception;
    }
    return _interleave(lists);
  }

  /// Must be called when the user downloads an Unsplash photo (API terms).
  Future<void> trackDownload(Wallpaper wallpaper) async {
    if (wallpaper.source == WallpaperSource.unsplash) {
      await _unsplash.trackDownload(wallpaper);
    }
  }

  static List<Wallpaper> _interleave(List<List<Wallpaper>> lists) {
    final result = <Wallpaper>[];
    final seen = <String>{};
    final maxLength = lists.fold<int>(0, (m, l) => l.length > m ? l.length : m);
    for (var i = 0; i < maxLength; i++) {
      for (final list in lists) {
        if (i < list.length && seen.add(list[i].id)) {
          result.add(list[i]);
        }
      }
    }
    return result;
  }
}
