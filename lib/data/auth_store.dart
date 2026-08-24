import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthStore {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  final ValueNotifier<User?> user = ValueNotifier<User?>(null);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn? _google;

  static const String _webGoogleClientId =
      '888637651520-4115251u0gqb3sd7b5a2vrgqtq0kigkm.apps.googleusercontent.com';

  GoogleSignIn get _googleSignIn {
    return _google ??= (kIsWeb
        ? GoogleSignIn(clientId: _webGoogleClientId)
        : GoogleSignIn());
  }

  bool _initialized = false;
  StreamSubscription<User?>? _sub;

  Future<void> initialize() async {
    if (_initialized) return;
    user.value = _auth.currentUser;
    _sub = _auth.authStateChanges().listen((u) {
      user.value = u;
    });
    _initialized = true;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final current = cred.user;
    if (current != null && !current.emailVerified) {
      await current.sendEmailVerification();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    final current = _auth.currentUser;
    if (current != null && !current.emailVerified) {
      await current.sendEmailVerification();
    }
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
    user.value = _auth.currentUser;
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      await _auth.signInWithPopup(provider);
      return;
    }

    final account = await _googleSignIn.signIn();
    if (account == null) return;

    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    final google = _googleSignIn;
    try {
      await google.disconnect();
    } catch (_) {
      try {
        await google.signOut();
      } catch (_) {
        // Firebase sign-out below still clears the app session.
      }
    } finally {
      await _auth.signOut();
      user.value = null;
    }
  }
}
