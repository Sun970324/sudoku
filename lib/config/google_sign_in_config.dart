/// The Web OAuth Client ID Google Sign-In needs as `serverClientId` to
/// return an ID token (required on Android; harmless elsewhere). Empty until
/// the Google Cloud Console project is set up — see the Phase 1 plan.
class GoogleSignInConfig {
  static const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  static bool get isConfigured => serverClientId.isNotEmpty;
}
