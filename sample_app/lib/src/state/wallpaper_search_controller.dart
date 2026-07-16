import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/wallpaper_repository.dart';
import 'explore_controller.dart';
import 'settings_controller.dart';

/// Drives the search screen: debounced queries against both providers,
/// paging, and a short list of recent searches persisted in SQLite.
class WallpaperSearchController extends ChangeNotifier {
  WallpaperSearchController({
    required this._repository,
    required AppDatabase database,
    required this._settings,
  }) : _db = database {
    _loadRecents();
  }

  static const _recentsKey = 'recent_searches';
  static const _maxRecents = 8;
  static const _debounce = Duration(milliseconds: 450);

  final WallpaperRepository _repository;
  final AppDatabase _db;
  final SettingsController _settings;

  final CategoryFeed feed = CategoryFeed();
  String _query = '';
  List<String> _recents = [];
  Timer? _debounceTimer;
  int _requestId = 0;
  bool _disposed = false;

  String get query => _query;
  List<String> get recents => List.unmodifiable(_recents);

  Future<void> _loadRecents() async {
    final raw = await _db.getSetting(_recentsKey);
    if (raw != null) {
      try {
        _recents = (json.decode(raw) as List).cast<String>();
        notifyListeners();
      } catch (_) {
        // Corrupt value; start fresh.
      }
    }
  }

  Future<void> _rememberQuery(String query) async {
    _recents
      ..removeWhere((q) => q.toLowerCase() == query.toLowerCase())
      ..insert(0, query);
    if (_recents.length > _maxRecents) {
      _recents = _recents.sublist(0, _maxRecents);
    }
    notifyListeners();
    await _db.setSetting(_recentsKey, json.encode(_recents));
  }

  Future<void> clearRecents() async {
    _recents = [];
    notifyListeners();
    await _db.setSetting(_recentsKey, json.encode(_recents));
  }

  /// Called on every keystroke; runs the search after a pause in typing.
  void onQueryChanged(String value) {
    _query = value.trim();
    _debounceTimer?.cancel();
    if (_query.isEmpty) {
      feed
        ..items.clear()
        ..status = FeedStatus.initial;
      notifyListeners();
      return;
    }
    _debounceTimer = Timer(_debounce, () => search(_query));
  }

  /// Runs [query] immediately (submit, recent-search tap).
  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _debounceTimer?.cancel();
    _query = q;

    final requestId = ++_requestId;
    feed
      ..items.clear()
      ..status = FeedStatus.loading
      ..nextPage = 1
      ..hasMore = true
      ..errorMessage = null;
    notifyListeners();

    await _fetch(requestId, page: 1);
    if (requestId == _requestId && feed.status == FeedStatus.ready) {
      await _rememberQuery(q);
    }
  }

  Future<void> loadMore() async {
    if (_query.isEmpty ||
        !feed.hasMore ||
        feed.status == FeedStatus.loading ||
        feed.status == FeedStatus.loadingMore) {
      return;
    }
    feed.status = FeedStatus.loadingMore;
    notifyListeners();
    await _fetch(_requestId, page: feed.nextPage);
  }

  Future<void> _fetch(int requestId, {required int page}) async {
    try {
      final items = await _repository.fetchPage(
        WallpaperCategory(_query, _query),
        page: page,
        filter: _settings.sourceFilter,
      );
      if (requestId != _requestId) return; // stale response
      final existing = feed.items.map((w) => w.id).toSet();
      feed.items.addAll(items.where((w) => existing.add(w.id)));
      feed
        ..nextPage = page + 1
        ..hasMore = items.isNotEmpty
        ..status = FeedStatus.ready
        ..errorMessage = null;
    } catch (e) {
      if (requestId != _requestId) return;
      feed.status = feed.items.isEmpty ? FeedStatus.error : FeedStatus.ready;
      feed.errorMessage = 'Could not search. Check your connection.';
      debugPrint('Search failed: $e');
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    // Fetches and recents-loading can complete after the search screen is
    // popped; notifying then would throw.
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
