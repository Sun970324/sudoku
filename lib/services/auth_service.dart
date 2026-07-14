import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/google_sign_in_config.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  bool _googleInitialized = false;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  bool get isAnonymous => currentUser?.isAnonymous ?? false;

  Future<void> signInAnonymously() => _client.auth.signInAnonymously();

  Future<void> signInWithGoogle() => _withGoogleIdToken(
        (idToken) => _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        ),
      );

  /// Links a Google identity onto the current (typically anonymous) session
  /// instead of starting a new one, so `auth.uid()` — and therefore the
  /// existing [UserProfile]'s rating/wins/losses — is preserved.
  Future<void> linkGoogle() => _withGoogleIdToken(
        (idToken) => _client.auth.linkIdentityWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        ),
      );

  Future<void> _withGoogleIdToken(
    Future<void> Function(String idToken) signIn,
  ) async {
    if (!GoogleSignInConfig.isConfigured) {
      throw const AuthServiceException(
          'Google sign-in is not configured yet.');
    }
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: GoogleSignInConfig.serverClientId,
      );
      _googleInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthServiceException(
          'Google sign-in did not return an ID token.');
    }
    await signIn(idToken);
  }

  Future<void> signInWithApple() => _withAppleIdToken(
        (idToken, rawNonce) => _client.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
          nonce: rawNonce,
        ),
      );

  /// See [linkGoogle] — same rationale, for Apple.
  Future<void> linkApple() => _withAppleIdToken(
        (idToken, rawNonce) => _client.auth.linkIdentityWithIdToken(
          provider: OAuthProvider.apple,
          idToken: idToken,
          nonce: rawNonce,
        ),
      );

  Future<void> _withAppleIdToken(
    Future<void> Function(String idToken, String rawNonce) signIn,
  ) async {
    final rawNonce = _generateNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: _sha256(rawNonce),
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthServiceException(
          'Apple sign-in did not return an identity token.');
    }
    await signIn(idToken, rawNonce);
  }

  Future<void> signOut() => _client.auth.signOut();

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256(String input) =>
      crypto.sha256.convert(utf8.encode(input)).toString();
}
