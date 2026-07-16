import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/wallpaper.dart';
import 'app_database.dart';
import 'wallpaper_repository.dart';

/// Downloads wallpapers to app storage and records them in the database.
///
/// Efficiency notes:
/// - Requests a CDN-resized rendition (see [Wallpaper.downloadUrl]) instead
///   of the multi-megabyte original.
/// - Streams the response straight to disk — the image never sits fully in
///   memory.
/// - Writes to a `.part` file and renames on success, so an interrupted
///   download can never leave a corrupt "completed" wallpaper behind.
class DownloadService {
  DownloadService({
    required AppDatabase database,
    required this._repository,
    http.Client? httpClient,
    Future<Directory> Function()? wallpaperDirProvider,
  })  : _db = database,
        _http = httpClient ?? http.Client(),
        _dirProvider = wallpaperDirProvider ?? _defaultWallpaperDir;

  static const _downloadTimeout = Duration(seconds: 60);

  final AppDatabase _db;
  final WallpaperRepository _repository;
  final http.Client _http;
  final Future<Directory> Function() _dirProvider;

  static Future<Directory> _defaultWallpaperDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'wallpapers'));
  }

  final Map<String, Future<String>> _inFlight = {};

  /// Downloads [wallpaper] (or reuses an existing download) and returns the
  /// local file path. Concurrent calls for the same wallpaper share one
  /// download.
  Future<String> download(Wallpaper wallpaper, {String? category}) {
    final inFlight = _inFlight[wallpaper.id];
    if (inFlight != null) return inFlight;
    final future =
        _download(wallpaper, category: category).whenComplete(() {
      _inFlight.remove(wallpaper.id);
    });
    _inFlight[wallpaper.id] = future;
    return future;
  }

  Future<String> _download(Wallpaper wallpaper, {String? category}) async {
    final existing = await _db.getDownload(wallpaper.id);
    final existingPath = existing?.filePath;
    if (existingPath != null && await File(existingPath).exists()) {
      return existingPath;
    }

    final dir = await _dirProvider();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName = '${wallpaper.id.replaceAll(':', '_')}.jpg';
    final file = File(p.join(dir.path, fileName));
    final partFile = File('${file.path}.part');

    final request = http.Request('GET', Uri.parse(wallpaper.downloadUrl()));
    final response = await _http.send(request).timeout(_downloadTimeout);
    if (response.statusCode != 200) {
      throw HttpException('Download failed (HTTP ${response.statusCode})',
          uri: request.url);
    }

    final sink = partFile.openWrite();
    try {
      await response.stream.timeout(_downloadTimeout).pipe(sink);
    } catch (e) {
      // pipe() closes the sink even on error; remove the partial file.
      await _deleteQuietly(partFile);
      rethrow;
    }
    await partFile.rename(file.path);

    await _db.insertDownload(
      wallpaper,
      filePath: file.path,
      category: category ?? existing?.category,
      createdAtMillis: existing?.createdAt.millisecondsSinceEpoch,
    );
    await _repository.trackDownload(wallpaper);
    return file.path;
  }

  /// Deletes the local file and the database record.
  Future<void> delete(DownloadedWallpaper download) async {
    final path = download.filePath;
    if (path != null) {
      await _deleteQuietly(File(path));
    }
    await _db.deleteDownload(download.wallpaper.id);
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Nothing useful to do; the next write will overwrite it.
    }
  }
}
