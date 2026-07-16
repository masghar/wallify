import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/auth_service.dart';
import '../data/download_sync_service.dart';
import 'downloads_controller.dart';

/// Google account state + cloud sync orchestration.
///
/// The auth stream is the single trigger for merging: any transition to a
/// signed-in user (interactive sign-in or already-signed-in at startup)
/// runs [DownloadSyncService.merge] once for that uid.
class AuthController extends ChangeNotifier {
  AuthController({
    required this._auth,
    required this._sync,
    required this._database,
    required this._downloads,
    this.isSupported = true,
  });

  static const _lastSyncedKey = 'last_synced_at';

  final AuthService _auth;
  final DownloadSyncService _sync;
  final AppDatabase _database;
  final DownloadsController _downloads;

  /// False on platforms where Google Sign-In isn't wired up (macOS for now);
  /// the UI hides the account section entirely.
  final bool isSupported;

  StreamSubscription<AppUser?>? _sub;
  bool _disposed = false;
  AppUser? _user;
  bool _syncing = false;
  DateTime? _lastSyncedAt;
  String? _lastMergedUid;

  AppUser? get user => _user;
  bool get signedIn => _user != null;
  bool get syncing => _syncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Call once after construction. Loads persisted state and starts
  /// listening to auth changes.
  Future<void> init() async {
    final saved = await _database.getSetting(_lastSyncedKey);
    if (saved != null) {
      _lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(int.parse(saved));
    }
    _user = _auth.currentUser;
    _sub = _auth.authStateChanges().listen(_onAuthChanged);
    if (_user != null) {
      unawaited(_runMerge(_user!.uid));
    }
    notifyListeners();
  }

  /// Returns false when the user cancelled; throws on real failures.
  Future<bool> signIn() async {
    final result = await _auth.signInWithGoogle();
    return result != null;
    // The auth stream event triggers the merge.
  }

  Future<void> signOut() => _auth.signOut();

  void _onAuthChanged(AppUser? user) {
    _user = user;
    if (user == null) {
      _lastMergedUid = null;
    } else if (_lastMergedUid != user.uid) {
      unawaited(_runMerge(user.uid));
    }
    notifyListeners();
  }

  Future<void> _runMerge(String uid) async {
    if (_syncing || _disposed) return;
    _lastMergedUid = uid;
    _syncing = true;
    notifyListeners();
    try {
      await _sync.merge();
      if (_disposed) return;
      await _downloads.load();
      _lastSyncedAt = DateTime.now();
      await _database.setSetting(
          _lastSyncedKey, '${_lastSyncedAt!.millisecondsSinceEpoch}');
    } catch (e) {
      // Offline or transient failure: local library is untouched; the next
      // app start (or next sign-in) retries the merge.
      debugPrint('Cloud merge failed: $e');
      _lastMergedUid = null;
    } finally {
      _syncing = false;
      // The merge is fire-and-forget; its continuation may outlive this
      // controller (widget disposed mid-merge). Never notify after dispose.
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
