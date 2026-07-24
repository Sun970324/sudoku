import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService, ProfileService? profileService})
      : _authService = authService ?? AuthService(),
        _profileService = profileService ?? ProfileService() {
    _authSubscription =
        _authService.authStateChanges.listen(_onAuthStateChange);
  }

  final AuthService _authService;
  final ProfileService _profileService;
  late final StreamSubscription<AuthState> _authSubscription;

  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfile? get profile => _profile;
  bool get isSignedIn => _authService.currentUser != null;
  bool get isAnonymous => _authService.isAnonymous;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _onAuthStateChange(AuthState state) {
    final user = state.session?.user;
    if (user == null) {
      _profile = null;
      notifyListeners();
    } else {
      _loadProfile(user.id);
    }
  }

  Future<void> _loadProfile(String userId) async {
    try {
      _profile = await _profileService.fetchProfile(userId);
    } catch (_) {
      _profile = null;
    }
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInAnonymously() => _run(_authService.signInAnonymously);
  Future<void> signInWithGoogle() => _run(_authService.signInWithGoogle);
  Future<void> signInWithApple() => _run(_authService.signInWithApple);
  Future<void> linkGoogle() => _run(_authService.linkGoogle);
  Future<void> linkApple() => _run(_authService.linkApple);
  Future<void> signOut() => _run(_authService.signOut);

  Future<void> updateUsername(String username) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;
    await _run(() async {
      await _profileService.updateUsername(userId, username);
      _profile = await _profileService.fetchProfile(userId);
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
