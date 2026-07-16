import 'package:cloud_firestore/cloud_firestore.dart';

import 'download_sync_service.dart';

/// Firestore-backed [CloudDownloadStore]: users/{uid}/downloads/{wallpaperId}.
class FirestoreDownloadStore implements CloudDownloadStore {
  FirestoreDownloadStore(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _downloads(String uid) =>
      _firestore.collection('users').doc(uid).collection('downloads');

  @override
  Future<Map<String, Map<String, Object?>>> fetchAll(String uid) async {
    final snapshot = await _downloads(uid).get();
    return {for (final doc in snapshot.docs) doc.id: doc.data()};
  }

  @override
  Future<void> put(String uid, String id, Map<String, Object?> data) =>
      _downloads(uid).doc(id).set(data);

  @override
  Future<void> delete(String uid, String id) =>
      _downloads(uid).doc(id).delete();
}
