import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/auth_store.dart';
import '../shell/main_shell.dart';
import 'sign_in_screen.dart';
import 'verify_email_screen.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<User?>(
      valueListenable: AuthStore.instance.user,
      builder: (context, user, _) {
        if (user == null) {
          return const SignInScreen();
        }
        final isGoogleUser = user.providerData.any((p) => p.providerId == 'google.com');
        if (!user.emailVerified && !isGoogleUser) {
          return const VerifyEmailScreen();
        }
        return const MainShell();
      },
    );
  }
}
