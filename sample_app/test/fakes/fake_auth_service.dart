import 'dart:async';

import 'package:sample_app/src/data/auth_service.dart';

class FakeAuthService implements AuthService {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  /// What the next signInWithGoogle() returns (null = user cancelled).
  AppUser? nextSignInResult;

  /// If set, the next signInWithGoogle() throws this instead.
  Object? nextSignInError;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser?> signInWithGoogle() async {
    final error = nextSignInError;
    if (error != null) {
      nextSignInError = null;
      throw error;
    }
    final user = nextSignInResult;
    if (user != null) {
      await emitSignIn(user);
    }
    return user;
  }

  @override
  Future<void> signOut() => emitSignOut();

  Future<void> emitSignIn(AppUser user) async {
    _current = user;
    _controller.add(user);
  }

  Future<void> emitSignOut() async {
    _current = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
