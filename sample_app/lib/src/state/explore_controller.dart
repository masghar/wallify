import 'package:flutter/foundation.dart';

import '../data/wallpaper_repository.dart';
import '../models/wallpaper.dart';
import 'settings_controller.dart';

enum FeedStatus { initial, loading, loadingMore, ready, error }

/// Paged feed state for one category.
class CategoryFeed {
  final List<Wallpaper> items = [];
  FeedStatus status = FeedStatus.initial;
  int nextPage = 1;
  bool hasMore = true;
  String? errorMessage;
}

/// Drives the Explore screen: selected category, paging, refresh.
class ExploreController extends ChangeNotifier {
  ExploreController({
    required this._repository,
    required this._settings,
  }) {
    _sourceFilter = _settings.sourceFilter;
    _settings.addListener(_onSettingsChanged);
  }

  final WallpaperRepository _repository;
  final SettingsController _settings;
  final Map<String, CategoryFeed> _feeds = {};

  WallpaperCategory _category = WallpaperCategory.defaults.first;
  late PhotoSourceFilter _sourceFilter;

  WallpaperCategory get category => _category;
  CategoryFeed get feed => _feeds.putIfAbsent(_category.title, CategoryFeed.new);

  void _onSettingsChanged() {
    if (_settings.sourceFilter != _sourceFilter) {
      _sourceFilter = _settings.sourceFilter;
      _feeds.clear();
      notifyListeners();
      loadInitial();
    }
  }

  Future<void> selectCategory(WallpaperCategory category) async {
    if (category.title == _category.title) return;
    _category = category;
    notifyListeners();
    if (feed.status == FeedStatus.initial) {
      await loadInitial();
    }
  }

  Future<void> loadInitial() async {
    final f = feed;
    if (f.status == FeedStatus.loading) return;
    f
      ..status = FeedStatus.loading
      ..errorMessage = null;
    notifyListeners();
    await _fetchInto(f, page: 1, replace: true);
  }

  Future<void> refresh() async {
    final f = feed;
    await _fetchInto(f, page: 1, replace: true);
  }

  Future<void> loadMore() async {
    final f = feed;
    if (!f.hasMore ||
        f.status == FeedStatus.loading ||
        f.status == FeedStatus.loadingMore) {
      return;
    }
    f.status = FeedStatus.loadingMore;
    notifyListeners();
    await _fetchInto(f, page: f.nextPage, replace: false);
  }

  Future<void> _fetchInto(CategoryFeed f,
      {required int page, required bool replace}) async {
    final requestCategory = _category;
    try {
      final items = await _repository.fetchPage(
        requestCategory,
        page: page,
        filter: _sourceFilter,
      );
      // Ignore stale responses after a category switch.
      if (_feeds[requestCategory.title] != f) return;

      if (replace) f.items.clear();
      final existing = f.items.map((w) => w.id).toSet();
      f.items.addAll(items.where((w) => existing.add(w.id)));
      f
        ..nextPage = page + 1
        ..hasMore = items.isNotEmpty
        ..status = FeedStatus.ready
        ..errorMessage = null;
    } catch (e) {
      if (_feeds[requestCategory.title] != f) return;
      // Keep showing existing items on load-more failures.
      f.status = f.items.isEmpty ? FeedStatus.error : FeedStatus.ready;
      f.errorMessage = 'Could not load wallpapers. Check your connection.';
      debugPrint('Explore fetch failed: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
