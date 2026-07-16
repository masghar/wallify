/// API keys for the photo providers.
///
/// Keys are NOT committed. Supply them at build time — the simple way is a
/// gitignored `api_keys.json` next to pubspec.yaml (copy
/// `api_keys.example.json`) plus `--dart-define-from-file`:
///   flutter run --dart-define-from-file=api_keys.json
///   flutter build apk --dart-define-from-file=api_keys.json
/// Get free keys at https://unsplash.com/developers and
/// https://www.pexels.com/api/.
class ApiKeys {
  ApiKeys._();

  static const String unsplashAccessKey = String.fromEnvironment(
    'UNSPLASH_ACCESS_KEY',
  );

  static const String pexelsApiKey = String.fromEnvironment(
    'PEXELS_API_KEY',
  );

  /// OAuth 2.0 *web* client ID of the Firebase project (google_sign_in needs
  /// it to mint ID tokens on Android).
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '1093583242801-c9312l82f32lnkqqircqa1fvocpfkhcb.apps.googleusercontent.com',
  );
}
