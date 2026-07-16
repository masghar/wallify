import 'dart:io' show Platform;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'src/config/api_keys.dart';
import 'src/data/app_database.dart';
import 'src/data/auth_service.dart';
import 'src/data/download_service.dart';
import 'src/data/download_sync_service.dart';
import 'src/data/firebase_auth_service.dart';
import 'src/data/firestore_download_store.dart';
import 'src/data/wallpaper_repository.dart';
import 'src/state/auth_controller.dart';
import 'src/state/downloads_controller.dart';
import 'src/state/explore_controller.dart';
import 'src/state/settings_controller.dart';
import 'src/ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Last line of defense: log uncaught errors instead of crashing. Wire
  // these into a crash reporter (Crashlytics/Sentry) before a Play release.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      debugPrint('Uncaught Flutter error: ${details.exceptionAsString()}');
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    return true;
  };

  // Load display/body fonts up front so text is measured with the real
  // metrics (late swaps clip labels in chips and buttons). Best-effort:
  // offline first launches fall back to system fonts.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.spaceGrotesk(),
      GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w500),
      GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
      GoogleFonts.inter(),
    ]);
  } catch (_) {
    // Keep going with fallback fonts.
  }

  final database = await AppDatabase.open();
  final repository = WallpaperRepository();
  final downloadService =
      DownloadService(database: database, repository: repository);

  final settings = SettingsController(database);
  await settings.load();

  // Google Sign-In + cloud sync: Android/iOS only (spec: hidden on macOS).
  // Start from the inert wiring; the Firebase branch overwrites it on
  // success. The app must never be blocked by cloud/auth, so any init
  // failure (missing platform options, misconfiguration) falls back to
  // running without sign-in instead of crashing before runApp.
  AuthService auth = _UnsupportedAuthService();
  DownloadSyncService sync = DownloadSyncService(
    database: database,
    store: _NoopDownloadStore(),
    currentUid: () => null,
  );
  var authSupported = false;
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      final firebaseAuth =
          FirebaseAuthService(serverClientId: ApiKeys.googleServerClientId);
      sync = DownloadSyncService(
        database: database,
        store: FirestoreDownloadStore(FirebaseFirestore.instance),
        currentUid: () => firebaseAuth.currentUser?.uid,
      );
      auth = firebaseAuth;
      authSupported = true;
    } catch (e) {
      debugPrint('Firebase init failed; running without sign-in: $e');
    }
  }

  final downloads = DownloadsController(
    database: database,
    downloadService: downloadService,
    syncService: sync,
  );
  await downloads.load();

  final authController = AuthController(
    auth: auth,
    sync: sync,
    database: database,
    downloads: downloads,
    isSupported: authSupported,
  );
  await authController.init();

  runApp(WallifyRoot(
    database: database,
    settings: settings,
    downloads: downloads,
    repository: repository,
    auth: authController,
  ));
}

/// Auth on platforms without Google Sign-In wiring (macOS): permanently
/// signed out; the UI never shows the account section there.
class _UnsupportedAuthService implements AuthService {
  @override
  Stream<AppUser?> authStateChanges() => const Stream.empty();
  @override
  AppUser? get currentUser => null;
  @override
  Future<AppUser?> signInWithGoogle() async => null;
  @override
  Future<void> signOut() async {}
}

class _NoopDownloadStore implements CloudDownloadStore {
  @override
  Future<Map<String, Map<String, Object?>>> fetchAll(String uid) async => {};
  @override
  Future<void> put(String uid, String id, Map<String, Object?> data) async {}
  @override
  Future<void> delete(String uid, String id) async {}
}

/// Wires app-wide dependencies into the widget tree.
class WallifyRoot extends StatelessWidget {
  const WallifyRoot({
    super.key,
    required this.database,
    required this.settings,
    required this.downloads,
    required this.repository,
    required this.auth,
  });

  final AppDatabase database;
  final SettingsController settings;
  final DownloadsController downloads;
  final WallpaperRepository repository;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: database),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: downloads),
        Provider.value(value: repository),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(
          create: (_) => ExploreController(
            repository: repository,
            settings: settings,
          ),
        ),
      ],
      child: const WallifyApp(),
    );
  }
}
