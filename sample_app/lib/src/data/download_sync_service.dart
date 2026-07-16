import 'package:flutter/foundation.dart';

import '../models/wallpaper.dart';
import 'app_database.dart';

/// The `downloads` columns a cloud doc may legitimately populate — the same
/// fields [DownloadSyncService._toCloudMap] writes. Anything else in a cloud
/// document is ignored rather than spread into the local insert, since an
/// unknown column would make the SQL insert throw.
const _kCloudColumns = [
  'source',
  'thumb_url',
  'full_url',
  'photographer',
  'photographer_url',
  'page_url',
  'avg_color',
  'width',
  'height',
  'category',
  'created_at',
];

/// Storage boundary for the per-user cloud copy of download records.
/// Production implementation is Firestore; tests use an in-memory map.
abstract class CloudDownloadStore {
  Future<Map<String, Map<String, Object?>>> fetchAll(String uid);
  Future<void> put(String uid, String id, Map<String, Object?> data);
  Future<void> delete(String uid, String id);
}

/// Mirrors the local `downloads` table to the signed-in user's cloud store.
///
/// SQLite stays the source of truth: [uploadRecord]/[deleteRecord] are
/// write-through calls made after local operations succeed, and [merge] is a
/// union by wallpaper id (cloud-only records land locally with a null
/// file_path; local-only records are uploaded). All methods are no-ops when
/// nobody is signed in.
class DownloadSyncService {
  DownloadSyncService({
    required AppDatabase database,
    required this._store,
    required this._currentUid,
  }) : _db = database;

  final AppDatabase _db;
  final CloudDownloadStore _store;
  final String? Function() _currentUid;

  Future<void> uploadRecord(DownloadedWallpaper download) async {
    final uid = _currentUid();
    if (uid == null) return;
    await _store.put(uid, download.wallpaper.id, _toCloudMap(download));
  }

  Future<void> deleteRecord(String wallpaperId) async {
    final uid = _currentUid();
    if (uid == null) return;
    await _store.delete(uid, wallpaperId);
  }

  /// Returns the number of records restored from the cloud.
  Future<int> merge() async {
    final uid = _currentUid();
    if (uid == null) return 0;

    final cloud = await _store.fetchAll(uid);
    final local = await _db.getAllDownloads();
    final localIds = {for (final d in local) d.wallpaper.id};

    var restored = 0;
    for (final entry in cloud.entries) {
      if (localIds.contains(entry.key)) continue;
      try {
        final row = _sanitizeCloudDoc(entry.key, entry.value);
        await _db.upsertDownloadRow(row);
        restored++;
      } catch (e) {
        debugPrint('Skipping malformed cloud download doc ${entry.key}: $e');
      }
    }
    for (final download in local) {
      if (cloud.containsKey(download.wallpaper.id)) continue;
      await _store.put(uid, download.wallpaper.id, _toCloudMap(download));
    }
    return restored;
  }

  /// The downloads row minus device-local file_path.
  static Map<String, Object?> _toCloudMap(DownloadedWallpaper d) =>
      d.wallpaper.toDbMap(
        category: d.category,
        createdAtMillis: d.createdAt.millisecondsSinceEpoch,
      )..remove('file_path');

  /// Builds a `downloads` row from a raw cloud document, restricted to the
  /// known columns and validated so a malformed doc (bad/missing fields,
  /// unexpected keys) can never reach the SQL insert. Throws on invalid
  /// input; callers are expected to catch and skip.
  static Map<String, Object?> _sanitizeCloudDoc(
      String id, Map<String, Object?> doc) {
    final source = doc['source'];
    if (source is! String ||
        !WallpaperSource.values.any((s) => s.name == source)) {
      throw FormatException('invalid source: $source');
    }
    for (final field in ['thumb_url', 'full_url', 'photographer']) {
      final value = doc[field];
      if (value is! String || value.isEmpty) {
        throw FormatException('invalid $field: $value');
      }
    }
    final createdAt = doc['created_at'];
    final row = <String, Object?>{
      for (final column in _kCloudColumns)
        if (doc.containsKey(column)) column: doc[column],
      'created_at': createdAt is int
          ? createdAt
          : DateTime.now().millisecondsSinceEpoch,
      'id': id,
      'file_path': null,
    };
    return row;
  }
}
