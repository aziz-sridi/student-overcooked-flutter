import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/theme/app_theme.dart';
import 'data/mascot_store.dart';
import 'data/task_store.dart';
import 'data/project_store.dart';
import 'data/theme_store.dart';
import 'data/notification_store.dart';
import 'data/auth_store.dart';
import 'features/auth/auth_gate_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {
    // Continue with default Firestore settings if platform/browser rejects overrides.
  }
  await AuthStore.instance.initialize();
  await ProjectStore.instance.initialize();
  await TaskStore.instance.initialize();
  await MascotStore.instance.initialize();
  await ThemeStore.instance.initialize();
  await NotificationStore.instance.initialize();
  runApp(const StudentOvercookedApp());
}

class StudentOvercookedApp extends StatelessWidget {
  const StudentOvercookedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeStore.instance.mode,
      builder: (context, ThemeMode mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Student Overcooked',
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: mode,
          home: const AuthGateScreen(),
        );
      },
    );
  }
}
