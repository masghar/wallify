import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/download_service.dart';
import '../data/download_sync_service.dart';
import '../models/wallpaper.dart';

/// Local downloads list backed by SQLite, mirrored to the cloud when a
/// [DownloadSyncService] is provided and a user is signed in.
class DownloadsController extends ChangeNotifier {
  DownloadsController({
    required AppDatabase database,
    required this._downloadService,
    DownloadSyncService? syncService,
  })  : _db = database,
        _sync = syncService;

  final AppDatabase _db;
  final DownloadService _downloadService;
  final DownloadSyncService? _sync;

  List<DownloadedWallpaper> _downloads = [];
  bool _loaded = false;
  final Set<String> _inProgress = {};

  List<DownloadedWallpaper> get downloads => _downloads;
  bool get loaded => _loaded;

  bool isDownloading(String wallpaperId) => _inProgress.contains(wallpaperId);

  bool isDownloaded(String wallpaperId) =>
      _downloads.any((d) => d.wallpaper.id == wallpaperId);

  Future<void> load() async {
    _downloads = await _db.getAllDownloads();
    _loaded = true;
    notifyListeners();
  }

  /// Downloads [wallpaper] and returns the local file path.
  Future<String> download(Wallpaper wallpaper, {String? category}) async {
    _inProgress.add(wallpaper.id);
    notifyListeners();
    try {
      final path =
          await _downloadService.download(wallpaper, category: category);
      await load();
      _mirrorUpload(wallpaper.id);
      return path;
    } finally {
      _inProgress.remove(wallpaper.id);
      notifyListeners();
    }
  }

  /// Fetches the image file for a cloud-restored record.
  Future<String> redownload(DownloadedWallpaper download) =>
      this.download(download.wallpaper, category: download.category);

  Future<void> delete(DownloadedWallpaper download) async {
    await _downloadService.delete(download);
    await load();
    unawaited(_swallow(_sync?.deleteRecord(download.wallpaper.id)));
  }

  /// Pushes the freshly written DB record to the cloud, fire-and-forget.
  void _mirrorUpload(String wallpaperId) {
    final sync = _sync;
    if (sync == null) return;
    final record =
        _downloads.where((d) => d.wallpaper.id == wallpaperId).firstOrNull;
    if (record == null) return;
    unawaited(_swallow(sync.uploadRecord(record)));
  }

  /// Cloud writes must never fail a local operation; Firestore queues them
  /// offline and the next merge reconciles anything that slipped through.
  static Future<void> _swallow(Future<void>? future) async {
    try {
      await future;
    } catch (e) {
      debugPrint('Cloud sync write failed (will reconcile on next merge): $e');
    }
  }
}
