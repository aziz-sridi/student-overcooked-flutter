import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common/app_top_bar.dart';
import '../shop/shop_screen.dart';
import '../../data/auth_store.dart';
import '../../data/notification_store.dart';
import '../profile/notification_settings_screen.dart';
import '../profile/theme_settings_screen.dart';
import '../auth/sign_in_screen.dart';
import '../auth/sign_up_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: AppTopBar(
              title: 'Profile',
              onShopTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                );
              },
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.progressTrack,
                        child: Icon(Icons.person, size: 34),
                      ),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<User?>(
                        valueListenable: AuthStore.instance.user,
                        builder: (context, user, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? user?.email ?? 'Student',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                user?.emailVerified == true ? 'Email verified' : 'Email not verified',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notification settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      NotificationStore.instance.initialize();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Theme and mascots'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()));
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: AuthStore.instance.user,
                    builder: (context, value, _) {
                      if (value == null) {
                        return Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                                child: const Text('Sign in'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                              child: const Text('Register'),
                            ),
                          ],
                        );
                      }

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout),
                        title: Text('Sign out (${value.displayName ?? value.email ?? 'Account'})'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await AuthStore.instance.signOut();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
