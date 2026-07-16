/// A signed-in Google user, decoupled from firebase_auth types.
class AppUser {
  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
}

/// Authentication boundary. The app only ever talks to this interface;
/// [FirebaseAuthService] implements it in production, tests use a fake.
abstract class AuthService {
  /// Emits the current user on every auth change (null = signed out).
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  /// Returns the signed-in user, or null if the user cancelled the flow.
  /// Throws on real failures (network, misconfiguration).
  Future<AppUser?> signInWithGoogle();

  Future<void> signOut();
}
