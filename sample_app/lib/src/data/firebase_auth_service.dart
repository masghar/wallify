import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

/// Production [AuthService]: google_sign_in v7 native account picker feeding
/// a firebase_auth credential sign-in.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({required this._serverClientId});

  final String _serverClientId;
  Future<void>? _init;

  Future<void> _ensureInitialized() =>
      _init ??= GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId,
      );

  @override
  Stream<AppUser?> authStateChanges() =>
      fb.FirebaseAuth.instance.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(fb.FirebaseAuth.instance.currentUser);

  @override
  Future<AppUser?> signInWithGoogle() async {
    await _ensureInitialized();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null; // user backed out — not an error
      }
      rethrow;
    }
    final credential = fb.GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    final result =
        await fb.FirebaseAuth.instance.signInWithCredential(credential);
    return _toAppUser(result.user);
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google session cleanup is best-effort; Firebase sign-out is what counts.
    }
    await fb.FirebaseAuth.instance.signOut();
  }

  static AppUser? _toAppUser(fb.User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
          photoUrl: user.photoURL,
        );
}
