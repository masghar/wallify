import 'package:sample_app/src/data/download_sync_service.dart';

class InMemoryDownloadStore implements CloudDownloadStore {
  /// uid -> wallpaperId -> document data
  final Map<String, Map<String, Map<String, Object?>>> docs = {};

  @override
  Future<Map<String, Map<String, Object?>>> fetchAll(String uid) async =>
      Map.of(docs[uid] ?? const {});

  @override
  Future<void> put(String uid, String id, Map<String, Object?> data) async {
    docs.putIfAbsent(uid, () => {})[id] = Map.of(data);
  }

  @override
  Future<void> delete(String uid, String id) async {
    docs[uid]?.remove(id);
  }
}
