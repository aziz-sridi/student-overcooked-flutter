import 'package:flutter/material.dart';
import '../../data/notification_store.dart';
import '../../core/theme/app_colors.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<bool>(
          valueListenable: NotificationStore.instance.enabled,
          builder: (context, enabled, _) {
            return ListTile(
              leading: const Icon(
                Icons.notifications_outlined,
                color: AppColors.burntOrange,
              ),
              title: const Text('Enable notifications'),
              trailing: Switch(
                value: enabled,
                onChanged: (v) => NotificationStore.instance.setEnabled(v),
              ),
            );
          },
        ),
      ),
    );
  }
}
