import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/data/auth_service.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  test('fake auth emits sign-in and sign-out through the stream', () async {
    final auth = FakeAuthService();
    final events = <AppUser?>[];
    final sub = auth.authStateChanges().listen(events.add);
    addTearDown(sub.cancel);

    const user = AppUser(uid: 'u1', displayName: 'Test', email: 't@x.com');
    auth.nextSignInResult = user;
    expect(await auth.signInWithGoogle(), user);
    expect(auth.currentUser, user);

    await auth.signOut();
    expect(auth.currentUser, isNull);

    await pumpEventQueue();
    expect(events, [user, null]);
  });

  test('cancelled sign-in returns null and stays signed out', () async {
    final auth = FakeAuthService(); // nextSignInResult defaults to null = cancel
    expect(await auth.signInWithGoogle(), isNull);
    expect(auth.currentUser, isNull);
  });
}
